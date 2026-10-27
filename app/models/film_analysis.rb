class FilmAnalysis < ApplicationRecord
  belongs_to :film
  belongs_to :superseded_by, class_name: "FilmAnalysis", optional: true
  has_many :analysis_qualities, dependent: :restrict_with_exception
  has_many :film_qualities, through: :analysis_qualities

  scope :draft, -> { where(published_at: nil) }
  scope :current, -> { where.not(published_at: nil).where(superseded_at: nil) }
  scope :at, ->(time) { where("published_at <= ? AND (superseded_at IS NULL OR superseded_at > ?)", time, time) }

  validate :single_draft
  validate :immutable_identity
  validate :document_shapes
  validate :publication_content, on: :publication
  before_destroy :ensure_unpublished!, prepend: true

  def edit_draft!(**attributes)
    attributes.assert_valid_keys(:content, :quality_candidates)
    ensure_unpublished!
    update!(attributes)
    self
  end

  def create_revision!(**attributes)
    attributes.assert_valid_keys(:content, :quality_candidates)
    film.film_analyses.create!(**{ content:, quality_candidates: }.merge(attributes))
  end

  def add_quality!(film_quality:, evidence_references:)
    ensure_unpublished!
    if analysis_qualities.exists?(film_quality:)
      errors.add(:quality_candidates, :duplicate_quality)
      raise ActiveRecord::RecordInvalid.new(self)
    end
    analysis_qualities.create!(film_quality:, evidence_references:)
  end

  def publish!(at:)
    validate_for_publication!
    quality_proposals.each do |quality_candidate|
      film_quality = FilmQuality.find_or_create!(quality_candidate:)
      add_quality!(film_quality:, evidence_references: quality_candidate.evidence_references)
    end
    update!(published_at: at)
  rescue ActiveModel::ValidationError
    errors.add(:quality_candidates, :invalid)
    raise ActiveRecord::RecordInvalid.new(self)
  end

  def supersede!(replacement:, at:)
    unless published_at? && superseded_at.nil? && replacement.film_id == film_id && replacement.id != id
      errors.add(:base, :invalid_supersession)
      raise ActiveRecord::RecordInvalid.new(self)
    end
    if at <= published_at
      errors.add(:published_at, :after_current)
      raise ActiveRecord::RecordInvalid.new(self)
    end
    update!(superseded_at: at, superseded_by: replacement)
  end

  private

  def validate_for_publication!
    ensure_unpublished!
    raise ActiveRecord::RecordInvalid.new(self) unless valid?(:publication)
  end

  def quality_proposals
    analysis_content = FilmKnowledge::AnalysisContent.new(content)
    quality_candidates.map { |attributes| FilmKnowledge::QualityCandidate.new(attributes, analysis_content:) }
  end

  def ensure_unpublished!
    raise FilmKnowledge::AnalysisNotEditable if published_at?
  end

  def immutable_identity
    errors.add(:base, :immutable_identity) if persisted? && will_save_change_to_film_id?
  end

  def single_draft
    if published_at.nil? && self.class.draft.where(film_id:).where.not(id:).exists?
      errors.add(:base, :draft_exists)
    end
  end

  def document_shapes
    errors.add(:content, :invalid) unless content.is_a?(Hash)
    errors.add(:quality_candidates, :invalid) unless quality_candidates.is_a?(Array) && quality_candidates.all? { |quality_candidate| quality_candidate.is_a?(Hash) }
  end

  def publication_content
    errors.add(:content, :incomplete_analysis) unless FilmKnowledge::AnalysisContent.new(content).valid?
    errors.add(:quality_candidates, :blank) if quality_candidates == []
  end
end

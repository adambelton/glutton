class FilmAnalysis < ApplicationRecord
  belongs_to :film
  belongs_to :superseded_by, class_name: "FilmAnalysis", optional: true
  has_many :analysis_qualities, dependent: :restrict_with_exception
  has_many :film_qualities, through: :analysis_qualities

  scope :draft, -> { where(published_at: nil) }
  scope :current, -> { where.not(published_at: nil).where(superseded_at: nil) }
  scope :at, ->(time) { where("published_at <= ? AND (superseded_at IS NULL OR superseded_at > ?)", time, time) }

  validate :single_draft
  validate :document_shapes
  validate :lifecycle_is_owned
  validate :publication_content, on: :publication
  around_save :protect_history
  around_destroy :protect_history, prepend: true

  def edit_draft!(**attributes)
    attributes.assert_valid_keys(:content, :quality_candidates)
    with_draft_lock { update!(attributes) }
    self
  end

  def validate_for_publication!
    ensure_editable!
    raise ActiveRecord::RecordInvalid.new(self) unless valid?(:publication)
  end

  def quality_proposals
    analysis_content = FilmKnowledge::AnalysisContent.new(content)
    quality_candidates.map { |attributes| FilmKnowledge::QualityCandidate.new(attributes, analysis_content:) }
  end

  def add_quality!(film_quality:, evidence_references:)
    ensure_editable!
    if analysis_qualities.exists?(film_quality:)
      errors.add(:quality_candidates, :duplicate_quality)
      raise ActiveRecord::RecordInvalid.new(self)
    end
    analysis_qualities.create!(film_quality:, evidence_references:)
  end

  def publish!(at:)
    validate_for_publication!
    if analysis_qualities.empty?
      errors.add(:quality_candidates, :blank)
      raise ActiveRecord::RecordInvalid.new(self)
    end
    @changing_lifecycle = true
    update!(published_at: at)
  ensure
    @changing_lifecycle = false
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
    @superseding = @changing_lifecycle = true
    update!(superseded_at: at, superseded_by: replacement)
  ensure
    @superseding = @changing_lifecycle = false
  end

  def with_draft_lock
    film.with_lock(requires_new: true) do
      reload
      ensure_editable!
      yield
    end
  end

  def ensure_editable!
    raise FilmKnowledge::AnalysisNotEditable if published_at?
  end

  private

  def protect_history
    Film.find(film_id_in_database || film_id).with_lock do
      stored = self.class.find_by(id: id)
      replacing_current = @superseding && stored&.published_at? && stored.superseded_at.nil? &&
        (changes_to_save.keys - %w[superseded_at superseded_by_id updated_at]).empty?
      if stored&.published_at? && !replacing_current
        raise FilmKnowledge::AnalysisNotEditable
      end
      yield
    end
  end

  def lifecycle_is_owned
    if persisted? && will_save_change_to_film_id?
      errors.add(:base, :immutable_identity)
    end
    if !@changing_lifecycle && (will_save_change_to_published_at? || will_save_change_to_superseded_at? || will_save_change_to_superseded_by_id?)
      errors.add(:base, :managed_lifecycle)
    end
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

class Film < ApplicationRecord
  has_many :film_qualities, dependent: :restrict_with_exception
  has_many :qualities, through: :film_qualities

  def ready_for_quality_assessment?
    tmdb_metadata? && wikipedia_context?
  end

  def import!(tmdb_data:, wikipedia_context:)
    raise FilmKnowledge::ImportIncomplete.new(stage: :persistence, reason: :existing_film) if persisted?
    unless FilmKnowledge::WikipediaContext.usable?(wikipedia_context, tmdb_id:)
      raise FilmKnowledge::ImportIncomplete.new(stage: :wikipedia, reason: :invalid_response)
    end
    self.title = tmdb_data.fetch(:title)
    self.release_date = tmdb_data.fetch(:release_date)
    self.tmdb_metadata = tmdb_data.fetch(:tmdb_metadata)
    unless tmdb_metadata?
      raise FilmKnowledge::ImportIncomplete.new(stage: :tmdb, reason: :invalid_response)
    end
    self.wikipedia_context = wikipedia_context
    self.wikidata_id = wikipedia_context.fetch("wikidata_id")
    save!
    self
  end

  validates :title, presence: true
  validates :tmdb_id, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true, allow_nil: true
  validates :wikidata_id, format: { with: /\AQ[1-9][0-9]*\z/ }, allow_nil: true
  validate :source_objects

  private

  def wikipedia_context?
    FilmKnowledge::WikipediaContext.usable?(wikipedia_context, tmdb_id:) && wikipedia_context["wikidata_id"] == wikidata_id
  end

  def tmdb_metadata?
    tmdb_metadata.is_a?(Hash) && tmdb_metadata["details"].is_a?(Hash)
  end

  def source_objects
    errors.add(:tmdb_metadata, :invalid) unless tmdb_metadata.is_a?(Hash)
    errors.add(:wikipedia_context, :invalid) unless wikipedia_context.is_a?(Hash)
  end
end

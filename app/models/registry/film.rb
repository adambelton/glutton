module Registry
  class Film < ApplicationRecord
    has_many :film_qualities, dependent: :restrict_with_exception
    has_many :film_quality_evals, dependent: :restrict_with_exception
    has_many :qualities, through: :film_qualities

    scope :without_qualities, -> { where.missing(:film_qualities) }

    def tmdb_details
      TmdbMetadata.new(tmdb_metadata)
    end

    def has_source_context?
      tmdb_metadata? && wikipedia_context?
    end

    def has_film_qualities?
      film_qualities.exists?
    end

    def import!(tmdb_data:, wikipedia_context:)
      raise Registry::ImportIncomplete.new(stage: :persistence, reason: :existing_film) if persisted?
      unless Registry::WikipediaContext.usable?(wikipedia_context, tmdb_id:)
        raise Registry::ImportIncomplete.new(stage: :wikipedia, reason: :invalid_response)
      end
      self.title = tmdb_data.fetch(:title)
      self.release_date = tmdb_data.fetch(:release_date)
      self.tmdb_metadata = tmdb_data.fetch(:tmdb_metadata)
      unless tmdb_metadata?
        raise Registry::ImportIncomplete.new(stage: :tmdb, reason: :invalid_response)
      end
      self.wikipedia_context = wikipedia_context
      self.wikidata_id = wikipedia_context.fetch("wikidata_id")
      save!
      self
    end

    def refresh_tmdb!(tmdb_data:)
      self.title = tmdb_data.fetch(:title)
      self.release_date = tmdb_data.fetch(:release_date)
      self.tmdb_metadata = tmdb_data.fetch(:tmdb_metadata)
      raise Registry::InvalidTmdbResponse, "TMDB metadata is incomplete" unless tmdb_metadata?

      save!
      self
    end

    validates :title, presence: true
    validates :tmdb_id, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true, allow_nil: true
    validates :wikidata_id, format: { with: /\AQ[1-9][0-9]*\z/ }, allow_nil: true
    validate :source_objects

    private

    def wikipedia_context?
      Registry::WikipediaContext.usable?(wikipedia_context, tmdb_id:) && wikipedia_context["wikidata_id"] == wikidata_id
    end

    def tmdb_metadata?
      tmdb_metadata.is_a?(Hash) && tmdb_metadata["details"].is_a?(Hash)
    end

    def source_objects
      errors.add(:tmdb_metadata, :invalid) unless tmdb_metadata.is_a?(Hash)
      errors.add(:wikipedia_context, :invalid) unless wikipedia_context.is_a?(Hash)
    end
  end
end

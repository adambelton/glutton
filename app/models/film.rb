class Film < ApplicationRecord
  has_many :film_analyses, dependent: :restrict_with_exception

  def edit_analysis!(**attributes)
    attributes.assert_valid_keys(:content, :quality_candidates)
    film = Film.find(id)
    film.with_lock(requires_new: true) do
      draft = film.film_analyses.draft.first
      if draft
        draft.edit_draft!(**attributes)
      else
        current = film.film_analyses.current.first
        if current
          current.create_revision!(**attributes)
        else
          film.film_analyses.create!(**attributes)
        end
      end
    end
  end

  def tmdb_metadata?
    !!metadata.dig("tmdb", "details")
  end

  def fill_tmdb_metadata!(metadata:)
    update!(metadata: self.metadata.merge(metadata)) unless tmdb_metadata?
    self
  end

  def can_generate_analysis?
    !!tmdb_id && tmdb_metadata? && !film_analyses.exists?
  end

  def analysis_generation_input
    source = { "id" => "TMDB", "reference" => "https://www.themoviedb.org/movie/#{tmdb_id}" }
    vocabulary = FilmQuality.order(:id).map { |quality| quality.attributes.slice("id", "name", "dimension") }
    { film: attributes.slice("id", "tmdb_id", "title", "release_date", "metadata"),
      sources: [ source ], version: "unknown", existing_vocabulary: vocabulary }
  end

  def save_generated_analysis!(**attributes)
    with_lock do
      raise FilmKnowledge::GenerationUnavailable unless can_generate_analysis?
      edit_analysis!(**attributes)
    end
  end

  def publish_analysis!
    film = Film.find(id)
    film.with_lock(requires_new: true) do
      draft = film.film_analyses.draft.first
      raise FilmKnowledge::NoUnpublishedAnalysis unless draft

      timestamp = Time.current.floor(6)
      film.film_analyses.current.first&.supersede!(replacement: draft, at: timestamp)
      draft.publish!(at: timestamp)
      draft
    end
  end

  validates :title, presence: true
  validates :tmdb_id, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true, allow_nil: true
  validate :metadata_is_object

  private

  def metadata_is_object
    errors.add(:metadata, :invalid) unless metadata.is_a?(Hash)
  end
end

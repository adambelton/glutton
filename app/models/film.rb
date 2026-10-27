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
        inherited = current ? current.attributes.slice("content", "quality_candidates").symbolize_keys : {}
        film.film_analyses.create!(**inherited.merge(attributes))
      end
    end
  end

  def publish_analysis!
    FilmKnowledge::PublishAnalysis.call(film_id: id)
  end

  validates :title, presence: true
  validates :tmdb_id, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true, allow_nil: true
  validate :metadata_is_object

  private

  def metadata_is_object
    errors.add(:metadata, :invalid) unless metadata.is_a?(Hash)
  end
end

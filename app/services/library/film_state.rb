module Library
  class FilmState
    def self.call(user:, film:)
      FilmAccess.call(user:, film:) do |owner|
        film_id = film.id
        relationship = LibraryFilm.find_by(user_id: owner.id, film_id:)
        relationship&.library_state || { film_id:, classification: :unclassified, watched_at: nil }
      end
    end
  end
end

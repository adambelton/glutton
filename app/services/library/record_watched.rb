module Library
  class RecordWatched
    def self.call(user:, film:)
      FilmAccess.call(user:, film:) do |owner|
        film_id = film.id
        relationship = LibraryFilm.lock.find_by(user_id: owner.id, film_id:)
        relationship ||= LibraryFilmWatched.create!(user: owner, film_id:, watched_at: Time.current)
        relationship.library_state
      end
    end
  end
end

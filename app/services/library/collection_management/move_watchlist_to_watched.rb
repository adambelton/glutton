module Library
  module CollectionManagement
    class MoveWatchlistToWatched
      def self.call(user_id:, library_film_id:)
        LibraryFilm.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless user&.active?

          library_film = LibraryFilm.lock.find_by(user_id: user.id, id: library_film_id)
          raise Library::Errors::FilmUnavailable unless library_film.present?

          library_film.move_to_watched!
        end
      end
    end
  end
end

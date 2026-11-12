module Library
  module CollectionManagement
    class ChangeWatchedEntry
      def self.move_to_watchlist(user_id:, library_film_id:)
        change(user_id:, library_film_id:, &:move_to_watchlist!)
      end

      def self.remove(user_id:, library_film_id:)
        change(user_id:, library_film_id:, &:remove_from_watched!)
      end

      def self.change(user_id:, library_film_id:)
        LibraryFilm.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless user&.active?

          library_film = LibraryFilm.lock.find_by(user_id: user.id, id: library_film_id)
          raise Errors::FilmUnavailable unless library_film.present?

          yield library_film
        end
      end
      private_class_method :change
    end
  end
end

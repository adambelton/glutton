module Library
  module CollectionManagement
    class AddToWatchlist
      def self.call(user_id:, film_id:)
        LibraryFilm.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless user&.active?

          library_film = FindOrBuildLibraryFilm.call(user:, film_id:)
          raise Errors::FilmUnavailable unless library_film.present?

          library_film.add_to_watchlist!
        end
      end
    end
  end
end

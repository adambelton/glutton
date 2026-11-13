module Library
  module CollectionManagement
    class AddToWatchlist
      def self.call(user_id:, film_id:)
        LibraryFilm.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless user&.active?

          film = Registry::Film.find_by(id: film_id)
          raise Library::Errors::FilmUnavailable unless film.present?
          raise Library::Errors::AddToWatchlistUnavailable if LibraryFilm.exists?(user:, film:)

          LibraryFilm.new(user:, film:).add_to_watchlist!
        end
      end
    end
  end
end

module Library
  module CollectionManagement
    class AddToWatchlist
      extend Monitoring::Instrumentation
      instrument_class_operations :call, :call_with_locked_user, operation_method: :call

      def self.call(user_id:, film_id:)
        apply(film_id:) { Identity::User.lock.find_by(id: user_id) }
      end

      # The caller must hold this account's row lock in the enclosing transaction.
      def self.call_with_locked_user(user:, film_id:)
        apply(film_id:) { user }
      end

      def self.apply(film_id:)
        LibraryFilm.transaction(requires_new: true) do
          user = yield
          raise Identity::Errors::Unavailable unless user&.active?

          film = Registry::Film.find_by(id: film_id)
          raise Library::Errors::FilmUnavailable unless film.present?
          raise Library::Errors::AddToWatchlistUnavailable if LibraryFilm.exists?(user:, film:)

          LibraryFilm.new(user:, film:).add_to_watchlist!
        end
      end
      private_class_method :apply
    end
  end
end

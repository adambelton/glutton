module Library
  module CollectionManagement
    class MarkWatched
      extend Monitoring::Instrumentation
      instrument_class_operations :call

      def self.call(user_id:, film_id:)
        LibraryFilm.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless user&.active?

          film = Registry::Film.find_by(id: film_id)
          raise Errors::FilmUnavailable unless film.present?

          library_film = LibraryFilm.lock.find_by(user:, film:)
          if library_film.present?
            library_film.move_to_watched!
          else
            LibraryFilm.new(user:, film:).add_to_watched!
          end
        end
      end
    end
  end
end

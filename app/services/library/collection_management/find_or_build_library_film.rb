module Library
  module CollectionManagement
    class FindOrBuildLibraryFilm
      def self.call(user:, film_id:)
        film = Registry::Film.find_by(id: film_id)
        return unless film.present?

        LibraryFilm.lock.find_by(user:, film:) || LibraryFilm.new(user:, film:)
      end
    end
  end
end

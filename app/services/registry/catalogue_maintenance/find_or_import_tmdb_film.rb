module Registry
  module CatalogueMaintenance
    class FindOrImportTmdbFilm
      def self.call(tmdb_id:)
        film = Film.find_by(tmdb_id:)
        return film if film.present?

        ImportDiscoveredFilm.call(tmdb_id:)
      rescue Errors::ImportIncomplete => error
        raise unless error.existing_film?

        Film.find_by(tmdb_id:) || raise
      end
    end
  end
end

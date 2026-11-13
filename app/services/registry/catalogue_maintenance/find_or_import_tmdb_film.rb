module Registry
  module CatalogueMaintenance
    class FindOrImportTmdbFilm
      def self.call(tmdb_id:)
        film = Film.find_by(tmdb_id:)
        return film if film.present?

        begin
          film = ImportFilm.call(tmdb_id:)
        rescue Errors::ImportIncomplete => error
          raise unless error.stage == :persistence && error.reason == :existing_film

          return Film.find_by(tmdb_id:) || raise
        end
        AssignInitialFilmQualitiesJob.set(queue: :registry_assignment).perform_later(film_ids: [ film.id ])
        film
      end
    end
  end
end

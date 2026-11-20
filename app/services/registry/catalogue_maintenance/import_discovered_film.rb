module Registry
  module CatalogueMaintenance
    class ImportDiscoveredFilm
      def self.call(tmdb_id:)
        film = ImportFilm.call(tmdb_id:)
        if film.has_source_context?
          AssignInitialFilmQualitiesJob.set(queue: :registry_assignment).perform_later(film_ids: [ film.id ])
        end
        film
      end
    end
  end
end

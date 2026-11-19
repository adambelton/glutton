module Registry
  module CatalogueMaintenance
    class ImportDiscoveredFilm
      def self.call(tmdb_id:)
        film = ImportFilm.call(tmdb_id:)
        AssignInitialFilmQualitiesJob.set(queue: :registry_assignment).perform_later(film_ids: [ film.id ])
        film
      end
    end
  end
end

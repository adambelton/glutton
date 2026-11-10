module Registry
  module CatalogueMaintenance
    class RefreshTmdbFilm
      def self.call(film_id:, tmdb_client: Sources::TmdbClient)
        tmdb_id = Film.find(film_id).tmdb_id
        tmdb_data = Sources::FetchTmdbFilm.call(tmdb_id:, tmdb_client:)
        Film.transaction(requires_new: true) do
          film = Film.lock.find(film_id)
          # The source identity may have changed while the provider request was in flight.
          raise Registry::Errors::InvalidTmdbId, "TMDB identity changed during retrieval" unless film.tmdb_id == tmdb_id

          film.refresh_tmdb!(tmdb_data:)
        end
      end
    end
  end
end

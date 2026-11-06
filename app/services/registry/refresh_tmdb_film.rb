module Registry
  class RefreshTmdbFilm
    def self.call(film_id:, tmdb_client: TmdbClient)
      tmdb_id = Film.find(film_id).tmdb_id
      tmdb_data = FetchTmdbFilm.call(tmdb_id:, tmdb_client:)
      Film.transaction(requires_new: true) do
        film = Film.lock.find(film_id)
        # The source identity may have changed while the provider request was in flight.
        raise InvalidTmdbId, "TMDB identity changed during retrieval" unless film.tmdb_id == tmdb_id

        film.refresh_tmdb!(tmdb_data:)
      end
    end
  end
end

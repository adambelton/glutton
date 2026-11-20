module Library
  module TmdbFilmSearch
    class BuildTmdbFilmSearchResults
      Result = Data.define(:candidates, :entries, :start, :next_cursor)

      def self.call(user_id:)
        page = yield
        candidates = page.candidates
        films = Registry::Film.where(tmdb_id: candidates.map { |candidate| candidate.fetch(:tmdb_id) })
        tmdb_ids_by_film = films.pluck(:id, :tmdb_id).to_h
        entries = LibraryFilm.where(user_id:, film_id: tmdb_ids_by_film.keys)
          .index_by { |entry| tmdb_ids_by_film.fetch(entry.film_id) }
        Result.new(candidates:, entries:, start: page.start, next_cursor: page.next_cursor)
      end
    end
  end
end

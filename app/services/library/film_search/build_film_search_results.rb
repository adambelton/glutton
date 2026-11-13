module Library
  module FilmSearch
    class BuildFilmSearchResults
      PAGE_SIZE = 5
      Result = Data.define(:candidates, :total_pages, :entries, :batch, :batch_count)

      def self.call(user_id:, batch:)
        search = yield
        matches = search.fetch(:candidates)
        batch_count = [ (matches.size + PAGE_SIZE - 1) / PAGE_SIZE, 1 ].max
        batch = batch == "last" ? batch_count : [ batch.to_i, batch_count ].min
        candidates = matches.slice((batch - 1) * PAGE_SIZE, PAGE_SIZE)
        films = Registry::Film.where(tmdb_id: candidates.map { |candidate| candidate.fetch(:tmdb_id) })
        tmdb_ids_by_film = films.pluck(:id, :tmdb_id).to_h
        entries = LibraryFilm.where(user_id:, film_id: tmdb_ids_by_film.keys)
          .index_by { |entry| tmdb_ids_by_film.fetch(entry.film_id) }
        Result.new(candidates:, total_pages: [ search.fetch(:total_pages), 500 ].min, entries:, batch:, batch_count:)
      end
    end
  end
end

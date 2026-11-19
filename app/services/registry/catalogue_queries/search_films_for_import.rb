module Registry
  module CatalogueQueries
    class SearchFilmsForImport
      PAGE_SIZE = 5

      def self.call(query:, page:, batch:)
        result = Sources::SearchTmdbFilms.call(query:, page:)
        matches = result.fetch(:candidates)
        batch_count = [ (matches.size + PAGE_SIZE - 1) / PAGE_SIZE, 1 ].max
        batch = batch == "last" ? batch_count : [ batch.to_i, batch_count ].min
        candidates = matches.slice((batch - 1) * PAGE_SIZE, PAGE_SIZE)
        registry_ids = Film.where(tmdb_id: candidates.pluck(:tmdb_id)).pluck(:tmdb_id, :id).to_h
        result.merge(candidates:, registry_ids:, batch:, batch_count:)
      end
    end
  end
end

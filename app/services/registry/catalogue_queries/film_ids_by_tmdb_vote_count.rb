module Registry
  module CatalogueQueries
    class FilmIdsByTmdbVoteCount
      def self.call(excluding_ids:, limit:, offset: 0)
        Film.where.not(id: excluding_ids).pluck(:id, :tmdb_metadata)
          .map { |film_id, metadata| [ film_id, Sources::TmdbMetadata.new(metadata).vote_count ] }
          # Valid vote counts are nonnegative; missing values sort after zero.
          .sort_by { |film_id, vote_count| [ -(vote_count || -1), film_id ] }
          .slice(offset, limit).to_a.map(&:first)
      end
    end
  end
end

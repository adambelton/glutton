module Registry
  module CatalogueQueries
    class FilmIdsByTmdbVoteCount
      VOTE_COUNT = Arel.sql(<<~SQL.squish).freeze
        CASE
          WHEN jsonb_typeof(tmdb_metadata #> '{details,vote_count}') = 'number'
            AND (tmdb_metadata #>> '{details,vote_count}') ~ '^[0-9]+$'
          THEN (tmdb_metadata #>> '{details,vote_count}')::numeric
        END DESC NULLS LAST
      SQL

      def self.call(excluding_ids:, limit:, offset: 0)
        Film.where.not(id: excluding_ids).order(VOTE_COUNT, :id).offset(offset).limit(limit).pluck(:id)
      end
    end
  end
end

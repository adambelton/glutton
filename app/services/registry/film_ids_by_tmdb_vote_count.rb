module Registry
  class FilmIdsByTmdbVoteCount
    def self.call(excluding_ids:, limit:)
      Film.where.not(id: excluding_ids).pluck(:id, :tmdb_metadata)
        .map { |film_id, metadata| [ film_id, TmdbMetadata.new(metadata).vote_count ] }
        # Valid vote counts are nonnegative; missing values sort after zero.
        .sort_by { |film_id, vote_count| [ -(vote_count || -1), film_id ] }
        .first(limit).map(&:first)
    end
  end
end

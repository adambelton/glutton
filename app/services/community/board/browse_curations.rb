module Community
  module Board
    class BrowseCurations
      POSTER_LIMIT = 5
      BoardEntry = Data.define(:curation, :poster_films, :film_count, :endorsement_count, :comment_count)

      def self.card_entries(post_ids:, comment_counts:)
        curations = PostCommunityCuration.where(id: post_ids).preload(:author, visible_film_endorsements: :film)
        curations.index_with do |curation|
          nominations = curation.nominated_films
          BoardEntry.new(curation:, poster_films: nominations.first(POSTER_LIMIT).map(&:first), film_count: nominations.size,
            endorsement_count: nominations.sum { |_, endorsements| endorsements.size }, comment_count: comment_counts.fetch(curation.id, 0))
        end.transform_keys(&:id)
      end

      def self.matching(query:)
        return PostCommunityCuration.all if query.blank?

        pattern = "%#{PostCommunityCuration.sanitize_sql_like(query)}%"
        film_ids = ::Registry::Film.matching_title(query).select(:id)
        post_ids = FilmEndorsement.visible_nominations.where(film_id: film_ids).select(:post_id)

        PostCommunityCuration.where("posts.title ILIKE :pattern OR posts.description ILIKE :pattern", pattern:)
          .or(PostCommunityCuration.where(id: post_ids))
      end
    end
  end
end

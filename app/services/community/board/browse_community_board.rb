module Community
  module Board
    class BrowseCommunityBoard
      PAGE_SIZE = 10
      DebriefEntry = Data.define(:film, :debrief, :comment_count)

      def initialize(watched_films:, matching_film_ids:, query:)
        @query = query
        @watched_films = watched_films
        @matching_film_ids = matching_film_ids
      end

      def page(number:)
        page = CountedPage.load(board_rows, number:, page_size: PAGE_SIZE)
        post_ids = page.entries.filter_map(&:post_id)
        comment_counts = Comment.joins(:content).where(post_id: post_ids).group(:post_id).count
        curations = BrowseCurations.card_entries(post_ids:, comment_counts:)
        debriefs = PostFilmDebrief.where(id: post_ids).includes(:film).index_by(&:id)
        placeholders = yield page.entries.filter_map(&:placeholder_film_id)

        entries = page.entries.filter_map do |row|
          if (film = placeholders[row.placeholder_film_id]).present?
            DebriefEntry.new(film:, debrief: nil, comment_count: 0)
          elsif (debrief = debriefs[row.post_id]).present?
            DebriefEntry.new(film: debrief.film, debrief:, comment_count: comment_counts.fetch(debrief.id, 0))
          else
            curations[row.post_id]
          end
        end
        page.with(entries:)
      end

      private

      def board_rows
        watched = Post.from(@watched_films, :watched_films)
        debriefs = PostFilmDebrief.where(film_id: watched.select("watched_films.film_id"))
        curations = BrowseCurations.matching(query: @query) { @matching_film_ids }
        published = Post.where(id: curations.select(:id)).or(Post.where(id: debriefs.select(:id)))
        if @query.blank?
          return Post.with(board_results: published_rows(published)).from("board_results AS posts")
            .order(updated_at: :desc, post_id: :desc)
        end

        Post.with(board_results: [ placeholder_rows(watched), published_rows(published) ]).from("board_results AS posts")
          .order(:result_group, updated_at: :desc, film_title: :asc, post_id: :desc, placeholder_film_id: :asc)
      end

      def placeholder_rows(watched)
        watched.where.not(watched_films: { film_id: PostFilmDebrief.select(:film_id) })
          .select(<<~SQL.squish)
            NULL::bigint AS post_id, watched_films.film_id AS placeholder_film_id, 0 AS result_group,
            NULL::timestamp AS updated_at, watched_films.film_title
          SQL
      end

      def published_rows(published)
        published.select(<<~SQL.squish)
          posts.id AS post_id, NULL::bigint AS placeholder_film_id,
          CASE WHEN posts.film_id IS NULL THEN 2 ELSE 1 END AS result_group,
          posts.updated_at, NULL::text AS film_title
        SQL
      end
    end
  end
end

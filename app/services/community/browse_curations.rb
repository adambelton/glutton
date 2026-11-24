module Community
  class BrowseCurations
    PAGE_SIZE = 10
    POSTER_LIMIT = 5
    BoardEntry = Data.define(:curation, :poster_films, :film_count, :endorsement_count, :comment_count)

    def self.page(number:, query: "")
      curations = query.present? ? matching_curations(query) : PostCommunityCuration.all
      curations = curations.order(updated_at: :desc, id: :desc).preload(:author, film_endorsements: :film)
      page = CountedPage.load(curations, number:, page_size: PAGE_SIZE)
      comment_counts = Comment.joins(:content).where(post_id: page.entries.map(&:id)).group(:post_id).count
      entries = page.entries.map do |curation|
        films = curation.nominated_films.map(&:first)
        BoardEntry.new(curation:, poster_films: films.first(POSTER_LIMIT), film_count: films.size,
          endorsement_count: curation.film_endorsements.size, comment_count: comment_counts.fetch(curation.id, 0))
      end
      page.with(entries:)
    end

    def self.matching_curations(query)
      pattern = "%#{PostCommunityCuration.sanitize_sql_like(query)}%"
      film_ids = ::Registry::Film.matching_title(query).select(:id)
      post_ids = FilmEndorsement.where(film_id: film_ids).select(:post_id)

      PostCommunityCuration.where("posts.title ILIKE :pattern OR posts.prompt ILIKE :pattern", pattern:)
        .or(PostCommunityCuration.where(id: post_ids))
    end
    private_class_method :matching_curations

    def self.detail(id:, viewer:)
      curation = PostCommunityCuration.preload(film_endorsements: [ :film, { comment: { content: :author } } ]).find(id)
      nominated_films = curation.nominated_films
      library_films = Library::LibraryFilm.where(user: viewer, film_id: nominated_films.map { |film, _| film.id }).index_by(&:film_id)
      { curation:, nominated_films:, library_films:, can_respond: PostingAccess.allowed?(user: viewer),
        can_edit: curation.can_edit?(member: viewer), can_delete: curation.can_delete?(member: viewer) }
    end
  end
end

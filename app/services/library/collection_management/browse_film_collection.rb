module Library
  module CollectionManagement
    class BrowseFilmCollection
      PAGE_SIZE = 25
      UNRATED = "unrated".freeze
      RATING_FILTERS = [ *Ratings::Rating::Values::ALL, UNRATED ].freeze

      module Views
        WATCHLIST = "watchlist".freeze
        WATCHED = "watched".freeze
        ALL = [ WATCHLIST, WATCHED ].freeze
      end

      Page = Data.define(:entries, :next_page)

      def self.entries_by_film(user_id:, film_ids:)
        LibraryFilm.where(user_id:, film_id: film_ids).index_by(&:film_id)
      end

      def self.call(user_id:, view:, page:, ratings: [], title_query: "")
        user = Identity::User.find_by(id: user_id)
        raise Identity::Errors::Unavailable unless user&.active?

        library_films = case view
        when Views::WATCHLIST then LibraryFilm.watchlist.order(created_at: :desc, id: :desc)
        when Views::WATCHED then LibraryFilm.watched.order(watched_at: :desc, id: :desc)
        else raise ArgumentError, "Unknown Library view"
        end
        library_films = library_films.where(user_id: user.id)
        library_films = library_films.where(film_id: Registry::Film.matching_title(title_query).select(:id)) if title_query.present?
        if ratings.present?
          rating_films = Ratings::RatingFilm.where(user_id: user.id)
          matching = rating_films.joins(:ratings).merge(Ratings::Rating.current.where(value: ratings - [ UNRATED ]))
          filtered = library_films.where(film_id: matching.select(:film_id))
          if ratings.include?(UNRATED)
            filtered = filtered.or(library_films.where.not(film_id: rating_films.rated.select(:film_id)))
          end
          library_films = filtered
        end
        library_films = library_films.includes(:film).preload(rated_rating_film: :current_rating)
          .offset((page - 1) * PAGE_SIZE).limit(PAGE_SIZE + 1).to_a
        next_page = library_films.size > PAGE_SIZE
        Page.new(entries: library_films.first(PAGE_SIZE), next_page:)
      end
    end
  end
end

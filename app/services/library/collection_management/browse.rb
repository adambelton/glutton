module Library
  module CollectionManagement
    class Browse
      PAGE_SIZE = 25
      UNRATED = "unrated".freeze
      RATING_FILTERS = [ *Ratings::Rating::Values::ALL, UNRATED ].freeze

      module Views
        WATCHLIST = "watchlist".freeze
        WATCHED = "watched".freeze
        ALL = [ WATCHLIST, WATCHED ].freeze
      end

      Page = Data.define(:entries, :next_page)

      def self.call(user_id:, view:, page:, ratings: [])
        user = Identity::User.find_by(id: user_id)
        raise Identity::Errors::Unavailable unless user&.active?

        entries = case view
        when Views::WATCHLIST then LibraryFilm.where(watched: false)
        when Views::WATCHED then LibraryFilm.where(watched: true)
        else raise ArgumentError, "Unknown Library view"
        end
        entries = entries.where(user_id: user.id)
        if ratings.present?
          rating_films = Ratings::RatingFilm.where(user_id: user.id)
          matching = rating_films.joins(:ratings).merge(Ratings::Rating.current.where(value: ratings - [ UNRATED ]))
          filtered = entries.where(film_id: matching.select(:film_id))
          if ratings.include?(UNRATED)
            filtered = filtered.or(entries.where.not(film_id: rating_films.rated.select(:film_id)))
          end
          entries = filtered
        end
        entries = entries.includes(:film).preload(rated_rating_film: :current_rating)
          .order(created_at: :desc, id: :desc).offset((page - 1) * PAGE_SIZE).limit(PAGE_SIZE + 1).to_a
        next_page = entries.size > PAGE_SIZE
        Page.new(entries: entries.first(PAGE_SIZE), next_page:)
      end
    end
  end
end

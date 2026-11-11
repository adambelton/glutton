module Library
  module CollectionManagement
    class Browse
      PAGE_SIZE = 25

      module Views
        WATCHLIST = "watchlist".freeze
        WATCHED = "watched".freeze
        ALL = [ WATCHLIST, WATCHED ].freeze
      end

      Page = Data.define(:entries, :next_page)

      def self.call(user_id:, view:, page:)
        user = Identity::User.find_by(id: user_id)
        raise Identity::Errors::Unavailable unless user&.active?

        entries = case view
        when Views::WATCHLIST then LibraryFilm.where(watched: false)
        when Views::WATCHED then LibraryFilm.where(watched: true).preload(:rated_rating_film)
        else raise ArgumentError, "Unknown Library view"
        end
        entries = entries.where(user_id: user.id).includes(:film)
          .order(created_at: :desc, id: :desc).offset((page - 1) * PAGE_SIZE).limit(PAGE_SIZE + 1).to_a
        next_page = entries.size > PAGE_SIZE
        Page.new(entries: entries.first(PAGE_SIZE), next_page:)
      end
    end
  end
end

module Library
  module CollectionManagement
    class BrowseWatchedFilms
      def self.film_ids(user_id:)
        watched_entries(user_id:).select(:film_id)
      end

      def self.entry(user_id:, film_id:, lock: false)
        entries = watched_entries(user_id:)
        entries = entries.lock if lock
        entries.find_by(film_id:)
      end

      def self.films(user_id:, film_ids: nil, lock: false)
        entries = watched_entries(user_id:)
        entries = entries.where(film_id: film_ids) unless film_ids.nil?
        entries = entries.order(:film_id).lock if lock
        entries.preload(:film).map(&:film)
      end

      def self.watched_entries(user_id:)
        LibraryFilm.watched.where(user_id:)
      end
      private_class_method :watched_entries
    end
  end
end

module Community
  module FilmDebriefs
    class BrowseFilmDebriefs
      def self.watched_films(viewer:)
        ::Library::LibraryFilm.watched.where(user: viewer)
      end

      def self.detail(viewer:, post_id:, lock: false)
        debrief = PostFilmDebrief.find(post_id)
        debrief.require_view_access!(viewer:, lock:)
        debrief.lock! if lock
        debrief
      end
    end
  end
end

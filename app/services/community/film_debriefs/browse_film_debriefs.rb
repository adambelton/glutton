module Community
  module FilmDebriefs
    class BrowseFilmDebriefs
      def self.detail(viewer:, post_id:, lock: false)
        debrief = PostFilmDebrief.find(post_id)
        debrief.require_view_access!(viewer:) do |user_id, film_id|
          Library::CollectionManagement::BrowseWatchedFilms.entry(user_id:, film_id:, lock:)
        end
        debrief.lock! if lock
        debrief
      end
    end
  end
end

module Community
  module FilmDebriefs
    class BrowseFilmDebriefs
      def self.watched_films(viewer:)
        ::Library::LibraryFilm.watched.where(user: viewer)
      end

      def self.detail(viewer:, film_id:, lock: false)
        Membership::Access.require!(user: viewer)
        watched = watched_films(viewer:)
        if lock
          watched.lock.find_by!(film_id:)
          PostFilmDebrief.lock.find_by!(film_id:)
        else
          PostFilmDebrief.where(film_id: watched.select(:film_id)).includes(:film).find_by!(film_id:)
        end
      end
    end
  end
end

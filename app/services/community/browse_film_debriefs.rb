module Community
  class BrowseFilmDebriefs
    def self.watched_films(viewer:)
      ::Library::LibraryFilm.watched.where(user: viewer)
    end

    def self.detail(viewer:, film_id:)
      PreviewAccess.require!(user: viewer)
      PostFilmDebrief.where(film_id: watched_films(viewer:).select(:film_id)).includes(:film).find_by!(film_id:)
    end
  end
end

module Community
  class OpenFilmDebrief
    def self.call(member_id:, film_id:)
      PostFilmDebrief.transaction do
        member = Identity::UserRegistered.lock.find_by(id: member_id)
        raise Errors::PostingUnavailable unless member.present? && PostingAccess.allowed?(user: member)

        library_film = BrowseFilmDebriefs.watched_films(viewer: member).lock.find_by(film_id:)
        raise Errors::FilmDebriefUnavailable unless library_film.present?

        PostFilmDebrief.open_for!(film: library_film.film)
      end
    end
  end
end

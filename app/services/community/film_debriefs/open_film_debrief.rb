module Community
  module FilmDebriefs
    class OpenFilmDebrief
      def self.call(community_user:, film_id:)
        Membership::WithProfileForUpdate.call(community_user:) do |community_user|
          raise Errors::PostingUnavailable unless community_user&.ready_to_post?

          library_film = Library::CollectionManagement::BrowseWatchedFilms.entry(user_id: community_user.user_id, film_id:, lock: true)
          raise Errors::FilmDebriefUnavailable unless library_film.present?

          PostFilmDebrief.open_for!(film: library_film.film)
        end
      end
    end
  end
end

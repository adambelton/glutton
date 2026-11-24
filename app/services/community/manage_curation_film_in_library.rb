module Community
  class ManageCurationFilmInLibrary
    def self.add_to_watchlist(curation_id:, user_id:, film_id:)
      with_nomination(curation_id:, user_id:, film_id:) do
        Library::CollectionManagement::AddToWatchlist.call(user_id:, film_id:)
      end
    end

    def self.mark_watched(curation_id:, user_id:, film_id:)
      with_nomination(curation_id:, user_id:, film_id:) do
        watchlist_entry = Library::LibraryFilm.watchlist.find_by(user_id:, film_id:)
        if watchlist_entry.present?
          Library::CollectionManagement::MoveWatchlistToWatched.call(user_id:, library_film_id: watchlist_entry.id)
        else
          Library::CollectionManagement::AddToWatched.call(user_id:, film_id:)
        end
      end
    end

    def self.with_nomination(curation_id:, user_id:, film_id:)
      PostCommunityCuration.transaction do
        viewer = Identity::UserRegistered.lock.find_by(id: user_id)
        raise Errors::MembershipRequired unless viewer.present? && PreviewAccess.allowed?(user: viewer)

        curation = PostCommunityCuration.lock.find(curation_id)
        raise Errors::NominationUnavailable unless curation.film_endorsements.exists?(film_id:)

        yield
      end
    end
    private_class_method :with_nomination
  end
end

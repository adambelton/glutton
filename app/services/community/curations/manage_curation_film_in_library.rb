module Community
  module Curations
    class ManageCurationFilmInLibrary
      def self.add_to_watchlist(curation_id:, user_id:, film_id:)
        with_nomination(curation_id:, user_id:, film_id:) do |viewer, nominated_film_id|
          Library::CollectionManagement::AddToWatchlist.call_with_locked_user(user: viewer, film_id: nominated_film_id)
        end
      end

      def self.mark_watched(curation_id:, user_id:, film_id:)
        with_nomination(curation_id:, user_id:, film_id:) do |viewer, nominated_film_id|
          Library::CollectionManagement::MarkWatched.call_with_locked_user(user: viewer, film_id: nominated_film_id)
        end
      end

      def self.with_nomination(curation_id:, user_id:, film_id:)
        PostCommunityCuration.transaction do
          viewer = Identity::UserRegistered.lock.find_by(id: user_id)
          raise Errors::MembershipRequired unless viewer.present? && Membership::Access.allowed?(user: viewer)

          curation = PostCommunityCuration.lock.find(curation_id)
          raise Errors::NominationUnavailable unless curation.visible_film_endorsements.exists?(film_id:)

          yield viewer, film_id
        end
      end
      private_class_method :with_nomination
    end
  end
end

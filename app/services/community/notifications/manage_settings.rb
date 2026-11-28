module Community
  module Notifications
    class ManageSettings
      Preferences = Data.define(:debrief, :discussion, :curation)

      def self.preferences(viewer:)
        Preferences.new(debrief: debrief_preference(viewer:), discussion: discussion_preference(viewer:), curation: curation_preference(viewer:))
      end

      def self.discussion_preference(viewer:)
        DiscussionNotificationPreference.find_or_initialize_by(user: viewer)
      end

      def self.curation_preference(viewer:)
        CurationNotificationPreference.find_or_initialize_by(user: viewer)
      end

      def self.update(viewer:, rating_values:, direct_replies:, authored_curations:, endorsed_film_comments:)
        with_member(viewer:) do |user|
          debrief_preference(viewer: user).select_ratings!(values: rating_values)
          discussion_preference(viewer: user).change_direct_replies!(enabled: direct_replies)
          curation_preference(viewer: user).change_settings!(authored_curations:, endorsed_film_comments:)
        end
      end

      def self.following_debrief?(viewer:, debrief:)
        post_preference = PostNotificationPreference.find_by(user: viewer, post: debrief, film_id: nil)
        return post_preference.following? if post_preference.present?

        follows_debrief_by_default?(viewer:, debrief:)
      end

      def self.update_debrief_post_preference(viewer:, post_id:, following:)
        with_member(viewer:) do |user|
          debrief = FilmDebriefs::BrowseFilmDebriefs.detail(viewer: user, post_id:, lock: true)
          post_preference = PostNotificationPreference.find_or_initialize_by(user:, post: debrief, film_id: nil)
          if following == follows_debrief_by_default?(viewer: user, debrief:)
            post_preference.destroy! if post_preference.persisted?
          else
            post_preference.change_mode!(mode: following ? "follow" : "mute")
          end
        end
      end

      def self.update_curation_preference(viewer:, post_id:, film_id:, following:)
        with_member(viewer:) do |user|
          curation = PostCommunityCuration.lock.find(post_id)
          if film_id.present? && !curation.visible_film_endorsements.exists?(film_id:)
            raise ActiveRecord::RecordNotFound
          end

          preference = PostNotificationPreference.find_or_initialize_by(user:, post: curation, film_id:)
          inherited = CurationFollowing.new(viewer: user, curation:, film_ids: Array(film_id)).inherited_following?(film_id:)
          clearing_post_follow = film_id.nil? && preference.following? && !following
          if clearing_post_follow || following == inherited
            preference.destroy! if preference.persisted?
          else
            preference.change_mode!(mode: following ? "follow" : "mute")
          end
        end
      end

      def self.follows_debrief_by_default?(viewer:, debrief:)
        debrief_preference(viewer:).follows_rating? do
          rating = Ratings::Rating.current.joins(:rating_film)
            .find_by(rating_films: { user_id: viewer.id, film_id: debrief.film_id })
          rating&.value || FilmDebriefNotificationPreference::UNRATED
        end
      end

      def self.debrief_preference(viewer:)
        FilmDebriefNotificationPreference.find_or_initialize_by(user: viewer)
      end

      def self.with_member(viewer:)
        ApplicationRecord.transaction do
          user = Identity::UserRegistered.lock.find_by(id: viewer.id)
          raise Errors::MembershipRequired unless user.present?

          Membership::Access.require!(user:)
          yield user
        end
      end
      private_class_method :follows_debrief_by_default?, :debrief_preference, :with_member
    end
  end
end

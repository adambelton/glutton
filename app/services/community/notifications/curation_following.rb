module Community
  module Notifications
    class CurationFollowing
      def initialize(viewer:, curation:, film_ids:)
        defaults = ManageSettings.curation_preference(viewer:)
        @follows_authored_curation = curation.community_user_id == viewer.id && defaults.authored_curations?
        @film_modes = PostNotificationPreference.where(user: viewer, post: curation, film_id: [ nil, *film_ids ])
          .pluck(:film_id, :mode).to_h
        @post_mode = @film_modes.delete(nil)
        @followed_endorsements = if defaults.endorsed_film_comments?
          curation.film_endorsements.active.where(user_id: viewer.id, film_id: film_ids).pluck(:film_id).to_set
        else
          Set.new
        end
      end

      def following?(film_id: nil)
        explicit = film_id.present? ? @film_modes[film_id] : @post_mode
        return explicit == "follow" if explicit.present?

        inherited_following?(film_id:)
      end

      def inherited_following?(film_id: nil)
        return @post_mode == "follow" if film_id.present? && @post_mode.present?

        @follows_authored_curation || @followed_endorsements.include?(film_id)
      end
    end
  end
end

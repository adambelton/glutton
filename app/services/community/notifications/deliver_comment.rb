module Community
  module Notifications
    class DeliverComment
      def self.call(content_id:)
        content = CommentContent.find_by(id: content_id)
        return unless content.present?

        comment = content.comment
        if comment.parent_id.present?
          recipient_id = CommentContent.find_by(comment_id: comment.parent_id)&.community_user_id
          return unless recipient_id.present?

          deliver(content:, recipient_id:) do |recipient|
            ManageSettings.discussion_preference(viewer: recipient).direct_replies?
          end
        elsif comment.film_endorsement_id.present?
          deliver_curation(content:)
        else
          deliver_debrief(content:)
        end
      end

      def self.deliver_debrief(content:)
        debrief = PostFilmDebrief.find_by(id: content.comment.post_id)
        return unless debrief.present?

        defaults = FilmDebriefNotificationPreference.following_films.select(:user_id)
        followers = PostNotificationPreference.where(post: debrief, mode: "follow", film_id: nil).select(:user_id)
        watched = Library::LibraryFilm.watched.where(film_id: debrief.film_id)
        watched.where(user_id: defaults).or(watched.where(user_id: followers)).find_each do |entry|
          deliver(content:, recipient_id: entry.user_id) do |recipient, post|
            ManageSettings.following_debrief?(viewer: recipient, debrief: post)
          end
        end
      end

      def self.deliver_curation(content:)
        endorsement = content.comment.film_endorsement
        return unless endorsement&.active?

        curation = endorsement.post
        endorsements = curation.film_endorsements.active.where(film_id: endorsement.film_id)
        followers = CurationNotificationPreference.where(endorsed_film_comments: true).select(:user_id)
        explicit_followers = PostNotificationPreference.where(post: curation, film_id: [ nil, endorsement.film_id ], mode: "follow")
        recipients = [ curation.community_user_id, *endorsements.where(user_id: followers).pluck(:user_id),
          *explicit_followers.distinct.pluck(:user_id) ]

        recipients.compact.uniq.each do |recipient_id|
          deliver(content:, recipient_id:, lock_post: true) do |recipient, post|
            next false unless post.film_endorsements.active.exists?(endorsement.id)

            CurationFollowing.new(viewer: recipient, curation: post, film_ids: [ endorsement.film_id ])
              .following?(film_id: endorsement.film_id)
          end
        end
      end

      def self.deliver(content:, recipient_id:, lock_post: false)
        return if recipient_id == content.community_user_id

        Notification.transaction do
          recipient = Identity::UserRegistered.lock.find_by(id: recipient_id)
          next unless recipient.present? && Membership::Access.allowed?(user: recipient)
          next unless CommentContent.exists?(content.id)
          next if recipient.community_user&.member_hidden?(content.community_user_id)

          post = Posts::ReadPost.call(id: content.comment.post_id, viewer: recipient, lock: lock_post)
          Notification.record_comment!(recipient:, content:) if yield(recipient, post)
        end
      rescue ActiveRecord::RecordNotFound
        # The recipient lost access, or moderation removed the source.
      rescue ActiveRecord::InvalidForeignKey
        # Content may be removed by moderation or account closure during delivery.
        raise if CommentContent.exists?(content.id)
      end

      private_class_method :deliver_debrief, :deliver_curation, :deliver
    end
  end
end

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
        else
          debrief = PostFilmDebrief.find_by(id: comment.post_id)
          return unless debrief.present?

          defaults = FilmDebriefNotificationPreference.following_films.select(:user_id)
          followers = PostNotificationPreference.where(post: debrief, mode: "follow").select(:user_id)
          watched = Library::LibraryFilm.watched.where(film_id: debrief.film_id)
          watched.where(user_id: defaults).or(watched.where(user_id: followers)).find_each do |entry|
            deliver(content:, recipient_id: entry.user_id) do |recipient, post|
              ManageSettings.following_debrief?(viewer: recipient, debrief: post)
            end
          end
        end
      end

      def self.deliver(content:, recipient_id:)
        return if recipient_id == content.community_user_id

        Notification.transaction do
          recipient = Identity::UserRegistered.lock.find_by(id: recipient_id)
          next unless recipient.present? && Membership::Access.allowed?(user: recipient)
          next unless CommentContent.exists?(content.id)
          next if recipient.community_user&.member_hidden?(content.community_user_id)

          post = Posts::ReadPost.call(id: content.comment.post_id, viewer: recipient)
          Notification.record_comment!(recipient:, content:) if yield(recipient, post)
        end
      rescue ActiveRecord::RecordNotFound
        # The recipient lost access, or moderation removed the source.
      rescue ActiveRecord::InvalidForeignKey
        # Content may be removed by moderation or account closure during delivery.
        raise if CommentContent.exists?(content.id)
      end

      private_class_method :deliver
    end
  end
end

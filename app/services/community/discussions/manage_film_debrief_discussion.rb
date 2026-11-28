module Community
  module Discussions
    class ManageFilmDebriefDiscussion
      def self.load_for_reply(post_id:, parent_id:, community_user:)
        require_posting!(community_user)
        debrief = FilmDebriefs::BrowseFilmDebriefs.detail(viewer: community_user.user, post_id:)
        parent = authored_comment(debrief, parent_id)
        parent.require_reply_visible_to!(community_user:)
        { debrief:, parent:, content: CommentContent.new }
      end

      def self.publish(post_id:, parent_id:, community_user:, body:)
        with_debrief(post_id:, community_user:) do |debrief, community_user|
          require_posting!(community_user)
          if parent_id.present?
            parent = authored_comment(debrief, parent_id)
            content = parent.publish_reply(community_user:, body:)
          else
            content = debrief.publish_comment(community_user:, body:)
          end
          DeliverCommentNotificationJob.enqueue!(content.id) if content.persisted?
          { debrief:, parent:, content: }
        end
      end

      def self.load_for_edit(post_id:, comment_id:, community_user:)
        raise Errors::CommentChangeUnavailable unless community_user.present?

        debrief = FilmDebriefs::BrowseFilmDebriefs.detail(viewer: community_user.user, post_id:)
        comment = authored_comment(debrief, comment_id)
        raise Errors::CommentChangeUnavailable unless comment.can_edit_inline?(community_user:)

        { debrief:, comment:, content: comment.content }
      end

      def self.edit(post_id:, comment_id:, community_user:, body:)
        with_debrief(post_id:, community_user:) do |debrief, community_user|
          comment = authored_comment(debrief, comment_id)
          content = comment.edit_body(community_user:, body:)
          { debrief:, comment:, content: }
        end
      end

      def self.delete(post_id:, comment_id:, community_user:)
        with_debrief(post_id:, community_user:) do |debrief, community_user|
          comment = authored_comment(debrief, comment_id)
          comment.delete_comment!(community_user:)
          { debrief:, selected_id: (comment.destroyed? ? comment.parent_id : comment.id) }
        end
      end

      def self.with_debrief(post_id:, community_user:)
        Membership::WithProfileForUpdate.call(community_user:) do |community_user|
          raise Errors::MembershipRequired unless community_user.present?

          debrief = FilmDebriefs::BrowseFilmDebriefs.detail(viewer: community_user.user, post_id:, lock: true)
          yield debrief, community_user
        end
      end

      def self.require_posting!(community_user)
        raise Errors::PostingUnavailable unless community_user&.ready_to_post?
      end

      def self.authored_comment(debrief, id)
        debrief.comments.joins(:content).preload(content: :community_user).find(id)
      end

      private_class_method :with_debrief, :require_posting!, :authored_comment
    end
  end
end

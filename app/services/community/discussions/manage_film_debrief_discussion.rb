module Community
  module Discussions
    class ManageFilmDebriefDiscussion
      def self.load_for_reply(post_id:, parent_id:, member:)
        debrief = FilmDebriefs::BrowseFilmDebriefs.detail(viewer: member, post_id:)
        require_posting!(member)
        parent = authored_comment(debrief, parent_id)
        { debrief:, parent:, content: CommentContent.new }
      end

      def self.publish(post_id:, parent_id:, member_id:, body:)
        with_debrief(post_id:, member_id:) do |debrief, member|
          require_posting!(member)
          if parent_id.present?
            parent = authored_comment(debrief, parent_id)
            content = parent.publish_reply(author: member, body:)
          else
            content = debrief.publish_comment(author: member, body:)
          end
          { debrief:, parent:, content: }
        end
      end

      def self.load_for_edit(post_id:, comment_id:, member:)
        debrief = FilmDebriefs::BrowseFilmDebriefs.detail(viewer: member, post_id:)
        comment = authored_comment(debrief, comment_id)
        raise Errors::CommentChangeUnavailable unless comment.can_edit_inline?(member:)

        { debrief:, comment:, content: comment.content }
      end

      def self.edit(post_id:, comment_id:, member_id:, body:)
        with_debrief(post_id:, member_id:) do |debrief, member|
          comment = authored_comment(debrief, comment_id)
          content = comment.edit_body(member:, body:)
          { debrief:, comment:, content: }
        end
      end

      def self.delete(post_id:, comment_id:, member_id:)
        with_debrief(post_id:, member_id:) do |debrief, member|
          comment = authored_comment(debrief, comment_id)
          comment.delete_comment!(member:)
          { debrief:, selected_id: (comment.destroyed? ? comment.parent_id : comment.id) }
        end
      end

      def self.with_debrief(post_id:, member_id:)
        PostFilmDebrief.transaction do
          member = Identity::UserRegistered.lock.find_by(id: member_id)
          raise Errors::MembershipRequired unless member.present?

          debrief = FilmDebriefs::BrowseFilmDebriefs.detail(viewer: member, post_id:, lock: true)
          yield debrief, member
        end
      end

      def self.require_posting!(member)
        raise Errors::PostingUnavailable unless Membership::PostingAccess.allowed?(user: member)
      end

      def self.authored_comment(debrief, id)
        debrief.comments.joins(:content).preload(content: :author).find(id)
      end

      private_class_method :with_debrief, :require_posting!, :authored_comment
    end
  end
end

module Community
  module Discussions
    class ManageCurationComment
      def self.load_for_edit(curation_id:, comment_id:, community_user:)
        curation = PostCommunityCuration.find(curation_id)
        comment = authored_comment(curation:, comment_id:)
        raise Errors::CommentChangeUnavailable unless comment.can_edit_inline?(community_user:)

        { curation:, comment:, content: comment.content }
      end

      def self.edit(curation_id:, comment_id:, community_user:, body:)
        with_comment(curation_id:, comment_id:, community_user:) do |curation, comment, community_user|
          content = comment.edit_body(community_user:, body:)
          { curation:, comment:, content: }
        end
      end

      def self.delete(curation_id:, comment_id:, community_user:)
        with_comment(curation_id:, comment_id:, community_user:) do |curation, comment, community_user|
          film_id = CurationDiscussion.film_id_for(comment)
          comment.delete_comment!(community_user:)
          selected_comment_id = comment.destroyed? ? comment.parent_id : comment.id
          nomination_visible = curation.visible_film_endorsements.exists?(film_id:)
          { curation:, film_id:, selected_comment_id:, nomination_visible: }
        end
      end

      def self.with_comment(curation_id:, comment_id:, community_user:)
        Membership::WithProfileForUpdate.call(community_user:) do |community_user|
          raise Errors::CommentChangeUnavailable unless community_user.present?

          curation = PostCommunityCuration.lock.find(curation_id)
          comment = authored_comment(curation:, comment_id:)
          yield curation, comment, community_user
        end
      end

      def self.authored_comment(curation:, comment_id:)
        curation.comments.joins(:content).preload(:content).find(comment_id)
      end

      private_class_method :with_comment, :authored_comment
    end
  end
end

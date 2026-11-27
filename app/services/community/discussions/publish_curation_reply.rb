module Community
  module Discussions
    class PublishCurationReply
      def self.load_for_reply(curation_id:, comment_id:, community_user:)
        raise Errors::PostingUnavailable unless community_user&.ready_to_post?

        curation = PostCommunityCuration.find(curation_id)
        parent = find_parent(curation:, comment_id:)
        parent.require_reply_visible_to!(community_user:)
        { curation:, parent:, reply: CommentContent.new }
      end

      def self.call(curation_id:, comment_id:, community_user:, body:)
        Membership::WithProfileForUpdate.call(community_user:) do |community_user|
          raise Errors::PostingUnavailable unless community_user&.ready_to_post?

          curation = PostCommunityCuration.lock.find(curation_id)
          parent = find_parent(curation:, comment_id:)
          reply = parent.publish_reply(community_user:, body:)
          curation.protect_from_contributions! if reply.persisted?
          { curation:, parent:, reply: }
        end
      end

      def self.find_parent(curation:, comment_id:)
        curation.comments.joins(:content).preload(content: :community_user).find(comment_id)
      end
      private_class_method :find_parent
    end
  end
end

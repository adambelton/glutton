module Community
  class Comment < ApplicationRecord
    belongs_to :post, class_name: "Community::Post", inverse_of: :comments
    belongs_to :film_endorsement, inverse_of: :comments, optional: true
    belongs_to :parent, class_name: "Community::Comment", optional: true
    belongs_to :root, class_name: "Community::Comment", optional: true
    has_one :content, class_name: "Community::CommentContent", inverse_of: :comment

    def publish_reply(community_user:, body:)
      reply = post.comments.build(parent: self, root: root || self)
      reply_content = reply.build_content(community_user:, body:)
      return reply_content unless reply_content.valid?

      reply.save!
      post.touch
      reply_content
    end

    def can_edit_inline?(community_user:)
      owned_by?(community_user:) && community_user.ready_to_post?
    end

    def can_delete?(community_user:)
      owned_by?(community_user:) && Membership::Access.participation_allowed?(user: community_user.user)
    end

    def edit_body(community_user:, body:)
      raise Errors::CommentChangeUnavailable unless can_edit_inline?(community_user:)

      content.edit_body(body:)
    end

    def delete_comment!(community_user:)
      raise Errors::CommentChangeUnavailable unless can_delete?(community_user:)

      remove_content!
    end

    def delete_reported_comment!(moderator:)
      Report.require_review_access!(moderator:)
      remove_content!
    end

    private

    def owned_by?(community_user:)
      content.present? && content.community_user_id == community_user&.id
    end

    def remove_content!
      if post.comments.exists?(parent_id: id)
        content.destroy!
      else
        destroy!
      end
    end
  end
end

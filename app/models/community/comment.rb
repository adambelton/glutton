module Community
  class Comment < ApplicationRecord
    belongs_to :post, class_name: "Community::Post", inverse_of: :comments
    belongs_to :film_endorsement, inverse_of: :comments, optional: true
    belongs_to :parent, class_name: "Community::Comment", optional: true
    belongs_to :root, class_name: "Community::Comment", optional: true
    has_one :content, class_name: "Community::CommentContent", inverse_of: :comment

    def publish_reply(author:, body:)
      reply = post.comments.build(parent: self, root: root || self)
      reply_content = reply.build_content(author:, body:)
      return reply_content unless reply_content.valid?

      reply.save!
      post.touch
      reply_content
    end

    def discussion_film_id
      (root || self).film_endorsement.film_id
    end

    def can_edit_inline?(member:)
      parent_id.present? && content&.author_id == member.id && PostingAccess.allowed?(user: member)
    end

    def can_delete?(member:)
      content&.author_id == member.id && member.active? && PreviewAccess.allowed?(user: member)
    end

    def edit_body(member:, body:)
      raise Errors::CommentChangeUnavailable unless can_edit_inline?(member:)

      content.edit_body(body:)
    end

    def delete_comment!(member:)
      raise Errors::CommentChangeUnavailable unless can_delete?(member:)

      if post.comments.exists?(parent_id: id)
        content.destroy!
      else
        destroy!
      end
    end
  end
end

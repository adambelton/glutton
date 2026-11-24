module Community
  class Comment < ApplicationRecord
    belongs_to :post, class_name: "Community::Post", inverse_of: :comments
    belongs_to :film_endorsement, inverse_of: :comment, optional: true
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
  end
end

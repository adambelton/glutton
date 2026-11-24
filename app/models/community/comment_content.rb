module Community
  class CommentContent < ApplicationRecord
    REPLY_LIMIT = 1_000

    belongs_to :comment, inverse_of: :content
    belongs_to :author, class_name: "Identity::UserRegistered"

    normalizes :body, with: ->(text) { text.strip }

    validates :body, presence: true
    validates :body, length: { maximum: REPLY_LIMIT }, if: -> { comment&.parent_id.present? }
  end
end

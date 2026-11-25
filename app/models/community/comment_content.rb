module Community
  class CommentContent < ApplicationRecord
    REPLY_LIMIT = 1_000

    belongs_to :comment, inverse_of: :content
    belongs_to :author, class_name: "Identity::UserRegistered"

    normalizes :body, with: ->(text) { text.strip }

    validates :body, presence: true
    validates :body, length: { maximum: REPLY_LIMIT }, if: -> { comment&.parent_id.present? }

    def edit_body(body:)
      self.body = body
      self.edited_at = Time.current if will_save_change_to_body?
      save
      self
    end
  end
end

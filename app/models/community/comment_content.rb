module Community
  class CommentContent < ApplicationRecord
    include Reportable

    BODY_LIMIT = 4_000

    belongs_to :comment, inverse_of: :content
    belongs_to :author, class_name: "Identity::UserRegistered"

    normalizes :body, with: ->(text) { text.strip }

    validates :body, presence: true
    validates :body, length: { maximum: BODY_LIMIT }, if: :will_save_change_to_body?

    def self.body_too_long?(body)
      normalize_value_for(:body, body).to_s.length > BODY_LIMIT
    end

    def reportable_attributes
      { "body" => body }
    end

    def reported_member
      author
    end

    def spoiler_free?
      comment.post.spoiler_free?
    end

    def edit_body(body:)
      self.body = body
      self.edited_at = Time.current if will_save_change_to_body?
      save
      self
    end
  end
end

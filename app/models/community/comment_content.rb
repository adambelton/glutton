module Community
  class CommentContent < ApplicationRecord
    belongs_to :comment, inverse_of: :content
    belongs_to :author, class_name: "Identity::UserRegistered"

    normalizes :body, with: ->(text) { text.strip }

    validates :body, presence: true
  end
end

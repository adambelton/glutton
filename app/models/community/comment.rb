module Community
  class Comment < ApplicationRecord
    belongs_to :post, class_name: "Community::Post"
    belongs_to :film_endorsement, inverse_of: :comment
    has_one :content, class_name: "Community::CommentContent", inverse_of: :comment
  end
end

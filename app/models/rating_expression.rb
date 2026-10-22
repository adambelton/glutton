class RatingExpression < ApplicationRecord
  MAX_TEXT_LENGTH = 2_000

  belongs_to :rating

  validates :text, presence: true, length: { maximum: MAX_TEXT_LENGTH }
end

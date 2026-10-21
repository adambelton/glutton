class RatingFilm < ApplicationRecord
  belongs_to :user
  belongs_to :film

  validates :film_id, uniqueness: { scope: :user_id }
  validates :dismissed, inclusion: { in: [ true, false ] }

  scope :dismissed, -> { where(dismissed: true) }
  scope :pending, -> { where(dismissed: false) }

  def can_dismiss?
    !dismissed?
  end

  def dismiss!
    raise Ratings::DismissalUnavailable unless can_dismiss?

    update!(dismissed: true)
    self
  end
end

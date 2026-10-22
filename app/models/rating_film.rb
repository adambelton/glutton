class RatingFilm < ApplicationRecord
  belongs_to :user
  belongs_to :film
  has_many :ratings

  validates :film_id, uniqueness: { scope: :user_id }
  validates :dismissed, inclusion: { in: [ true, false ] }

  scope :dismissed, -> { where(dismissed: true) }
  scope :rated, -> { where(id: Rating.select(:rating_film_id)) }
  scope :unrated, -> { where.not(id: Rating.select(:rating_film_id)) }
  scope :pending, -> { unrated.where(dismissed: false) }

  def can_submit_rating?
    !ratings.exists?
  end

  def submit_rating!(value:, expression_texts: [])
    raise Ratings::AlreadyRated unless can_submit_rating?

    rating = ratings.build(value:)
    rating.capture_expressions(expression_texts:)
    rating.save!
    rating
  end

  def can_dismiss?
    !dismissed?
  end

  def dismiss!
    raise Ratings::DismissalUnavailable unless can_dismiss?

    update!(dismissed: true)
    self
  end
end

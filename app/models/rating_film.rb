class RatingFilm < ApplicationRecord
  belongs_to :user
  belongs_to :film
  has_many :ratings
  has_one :current_rating, -> { order(id: :desc) }, class_name: "Rating"

  validates :film_id, uniqueness: { scope: :user_id }
  validates :dismissed, :held, inclusion: { in: [ true, false ] }

  scope :dismissed, -> { where(dismissed: true) }
  scope :rated, -> { where(id: Rating.select(:rating_film_id)) }
  scope :unrated, -> { where.not(id: Rating.select(:rating_film_id)) }
  scope :pending, -> { unrated.where(dismissed: false, held: false) }

  def can_submit_rating?
    !ratings.exists?
  end

  def submit_rating!(value:, expression_texts: [])
    raise Ratings::AlreadyRated unless can_submit_rating?

    create_rating!(value:, expression_texts:)
  end

  def revise_rating!(previous_rating_id:, value:, expression_texts: [])
    transaction(requires_new: true) do
      rating = ratings.order(id: :desc).first
      raise Ratings::RevisionUnavailable unless rating
      raise Ratings::StaleRating unless rating.id == previous_rating_id

      create_rating!(value:, expression_texts:)
    end
  end

  def can_hold?
    !held?
  end

  def hold!
    raise Ratings::HoldUnavailable unless can_hold?

    update!(held: true)
    self
  end

  def can_release_hold?
    held?
  end

  def release_hold!
    raise Ratings::HoldReleaseUnavailable unless can_release_hold?

    update!(held: false)
    self
  end

  def can_dismiss?
    !dismissed?
  end

  def dismiss!
    raise Ratings::DismissalUnavailable unless can_dismiss?

    update!(dismissed: true)
    self
  end

  private

  def create_rating!(value:, expression_texts:)
    # Check external values before nested attributes coerce expression text.
    unless expression_texts.is_a?(Array) && expression_texts.size <= Rating::MAX_EXPRESSIONS &&
        expression_texts.all? { |text| text.is_a?(String) }
      raise Ratings::InvalidExpressions
    end

    ratings.create!(value:, rating_expressions_attributes: expression_texts.map { |text| { text: } })
  end
end

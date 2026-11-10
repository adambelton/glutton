module Ratings
  class RatingFilm < ApplicationRecord
    belongs_to :user, class_name: "Identity::User"
    belongs_to :film, class_name: "Registry::Film"
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

    def submit_rating!(value:, notes: nil)
      transaction do
        raise Ratings::AlreadyRated unless can_submit_rating?

        create_rating!(value:, notes:, previous_rating: nil)
      end
    end

    def revise_rating!(previous_rating_id:, value:, notes: nil)
      transaction(requires_new: true) do
        previous_rating = ratings.order(id: :desc).first
        raise Ratings::RevisionUnavailable unless previous_rating.present?
        raise Ratings::StaleRating unless previous_rating.id == previous_rating_id

        create_rating!(value:, notes:, previous_rating:)
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

    def create_rating!(value:, notes:, previous_rating:)
      raise InvalidNotes unless notes.nil? || notes.is_a?(String)

      rating = ratings.create!(value:, notes: notes&.gsub(/\r\n?/, "\n").presence)
      rating.request_profile_refresh_if_notes_changed!(previous_rating:)
      rating
    end
  end
end

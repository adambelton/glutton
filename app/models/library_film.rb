class LibraryFilm < ApplicationRecord
  belongs_to :user
  belongs_to :film

  validates :film_id, uniqueness: { scope: :user_id }

  module RatingStatuses
    RATED = "rated".freeze
    AWAITING_RATING = "awaiting_rating".freeze
  end

  def rating_status
    nil
  end

  def can_rate?
    false
  end

  def can_edit_rating?
    false
  end

  def can_remove_from_watchlist?
    false
  end

  def can_remove_from_not_interested?
    false
  end

  def can_add_to_watchlist?
    false
  end

  def watchlist_addition_error
    Library::WatchlistUnavailable unless can_add_to_watchlist?
  end

  def can_mark_not_interested?
    false
  end

  def dismissal_error
    Library::DismissalUnavailable unless can_mark_not_interested?
  end

  def can_watch?
    false
  end

  def can_confirm_watched?
    false
  end

  def publish_event!(name:, correlation_id: nil, causation_id: nil)
    DomainEvents::Publish.call(user_id:, publisher: Library::EVENTS_PUBLISHING_DOMAIN,
      stream_key: "film:#{film_id}", name:, schema_version: 1,
      payload: { user_id:, film_id: }, correlation_id:, causation_id:)
  end

  def initialize(...)
    raise NotImplementedError, "Construct a LibraryFilm subtype" if self.class == LibraryFilm

    super
  end
end

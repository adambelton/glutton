module Library
  class LibraryFilm < ApplicationRecord
    belongs_to :user, class_name: "Identity::User"
    belongs_to :film, class_name: "Registry::Film"

    has_one :rated_rating_film, -> { rated }, class_name: "Ratings::RatingFilm",
      primary_key: [ :user_id, :film_id ], foreign_key: [ :user_id, :film_id ]

    validates :watched, inclusion: { in: [ true, false ] }
    validates :film_id, uniqueness: { scope: :user_id }

    module RatingStatuses
      RATED = "rated".freeze
      AWAITING_RATING = "awaiting_rating".freeze
    end

    def rating_status
      return unless watched?

      rated? ? RatingStatuses::RATED : RatingStatuses::AWAITING_RATING
    end

    def can_rate?
      watched? && !rated?
    end

    def can_edit_rating?
      watched? && rated?
    end

    def remove_from_watchlist!
      raise Errors::NotOnWatchlist unless can_remove_from_watchlist?

      transaction do
        destroy!
        publish_event!(name: Events::FILM_REMOVED_FROM_WATCHLIST)
      end
      self
    end

    def can_remove_from_watchlist?
      !watched?
    end

    def can_watch?
      !watched?
    end

    def mark_watched!(correlation_id: nil, causation_id: nil)
      raise Errors::AlreadyWatched unless can_watch?

      transaction do
        update!(watched: true)
        publish_event!(name: Events::FILM_MARKED_WATCHED, correlation_id:, causation_id:)
      end
      self
    end

    def add_to_watchlist!(correlation_id: nil, causation_id: nil)
      raise Errors::AddToWatchlistUnavailable if persisted?

      transaction do
        save!
        publish_event!(name: Events::FILM_ADDED_TO_WATCHLIST, correlation_id:, causation_id:)
      end
      self
    end

    def add_to_watchlist_from_event!(correlation_id:, causation_id:)
      return :ignored if persisted?

      add_to_watchlist!(correlation_id:, causation_id:)
      :processed
    end

    def mark_watched_from_event!(correlation_id:, causation_id:)
      return :ignored unless can_watch?

      mark_watched!(correlation_id:, causation_id:)
      :processed
    end

    private

    def publish_event!(name:, correlation_id: nil, causation_id: nil)
      DomainEvents::Publication::Publish.call(user_id:, publisher: Library::Events::PUBLISHING_DOMAIN,
        stream_key: "film:#{film_id}", name:, schema_version: 1,
        payload: { user_id:, film_id: }, correlation_id:, causation_id:)
    end

    def rated?
      rating_association = association(:rated_rating_film)
      rating_association.loaded? ? rating_association.target.present? : rating_association.scope.exists?
    end
  end
end

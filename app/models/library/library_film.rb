module Library
  class LibraryFilm < ApplicationRecord
    belongs_to :user, class_name: "Identity::User"
    belongs_to :film, class_name: "Registry::Film"

    has_one :rated_rating_film, -> { rated }, class_name: "Ratings::RatingFilm",
      primary_key: [ :user_id, :film_id ], foreign_key: [ :user_id, :film_id ]

    validates :watched, inclusion: { in: [ true, false ] }
    validates :film_id, uniqueness: { scope: :user_id }

    def can_rate?
      watched? && !rated?
    end

    def can_edit_rating?
      watched? && rated?
    end

    def current_rating
      rated_rating_film&.current_rating
    end

    def can_add_to_watchlist?
      new_record?
    end

    def add_to_watchlist!(correlation_id: nil, causation_id: nil)
      raise Errors::AddToWatchlistUnavailable unless can_add_to_watchlist?

      transaction do
        update!(watched: false)
        publish_event!(name: Events::FILM_ADDED_TO_WATCHLIST, correlation_id:, causation_id:)
      end
      self
    end

    def can_add_to_watched?
      new_record?
    end

    def add_to_watched!(correlation_id: nil, causation_id: nil)
      raise Errors::AddToWatchedUnavailable unless can_add_to_watched?

      save_as_watched!(correlation_id:, causation_id:)
    end

    def can_move_to_watchlist?
      persisted? && watched?
    end

    def move_to_watchlist!
      raise Errors::NotWatched unless can_move_to_watchlist?

      transaction do
        update!(watched: false)
        publish_event!(name: Events::FILM_ADDED_TO_WATCHLIST)
      end
      self
    end

    def can_move_to_watched?
      persisted? && !watched?
    end

    def move_to_watched!(correlation_id: nil, causation_id: nil)
      raise Errors::NotOnWatchlist unless persisted?
      raise Errors::AlreadyWatched unless can_move_to_watched?

      save_as_watched!(correlation_id:, causation_id:)
    end

    def can_remove_from_watchlist?
      persisted? && !watched?
    end

    def remove_from_watchlist!
      raise Errors::NotOnWatchlist unless can_remove_from_watchlist?

      transaction do
        destroy!
        publish_event!(name: Events::FILM_REMOVED_FROM_WATCHLIST)
      end
      self
    end

    def can_remove_from_watched?
      persisted? && watched?
    end

    def remove_from_watched!
      raise Errors::NotWatched unless can_remove_from_watched?

      transaction do
        destroy!
        publish_event!(name: Events::FILM_REMOVED_FROM_WATCHED)
      end
      self
    end

    private

    def save_as_watched!(correlation_id:, causation_id:)
      transaction do
        update!(watched: true)
        publish_event!(name: Events::FILM_MARKED_WATCHED, correlation_id:, causation_id:)
      end
      self
    end

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

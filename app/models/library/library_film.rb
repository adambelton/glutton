module Library
  class LibraryFilm < ApplicationRecord
    self.store_full_sti_class = false

    belongs_to :user, class_name: "Identity::User"
    belongs_to :film, class_name: "Registry::Film"

    validates :film_id, uniqueness: { scope: :user_id }

    module RatingStatuses
      RATED = "rated".freeze
      AWAITING_RATING = "awaiting_rating".freeze
    end

    def rating_status(rated: nil)
      nil
    end

    def can_rate?(rated: nil)
      false
    end

    def can_edit_rating?(rated: nil)
      false
    end

    def remove_from_watchlist!
      raise NotOnWatchlist unless can_remove_from_watchlist?

      transaction do
        destroy!
        publish_event!(name: Events::FILM_REMOVED_FROM_WATCHLIST)
      end
      self
    end

    def can_remove_from_watchlist?
      false
    end

    def remove_not_interested!
      raise NotMarkedNotInterested unless can_remove_from_not_interested?

      transaction do
        destroy!
        publish_event!(name: Events::FILM_DISMISSAL_REMOVED)
      end
      self
    end

    def can_remove_from_not_interested?
      false
    end

    def can_add_to_watchlist?
      false
    end

    def can_mark_not_interested?
      false
    end

    def can_watch?
      false
    end

    def can_confirm_watched?
      false
    end

    def publish_event!(name:, correlation_id: nil, causation_id: nil)
      DomainEvents::Publish.call(user_id:, publisher: Library::Events::PUBLISHING_DOMAIN,
        stream_key: "film:#{film_id}", name:, schema_version: 1,
        payload: { user_id:, film_id: }, correlation_id:, causation_id:)
    end

    def initialize(...)
      raise NotImplementedError, "Construct a LibraryFilm subtype" if self.class == LibraryFilm

      super
    end
  end
end

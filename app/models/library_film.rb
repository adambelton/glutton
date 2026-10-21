class LibraryFilm < ApplicationRecord
  belongs_to :user
  belongs_to :film

  validates :film_id, uniqueness: { scope: :user_id }

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

  def publish_event!(name:, classification:)
    DomainEvents::Publish.call(user_id:, publisher: Library::EVENTS_PUBLISHING_DOMAIN,
      stream_key: "film:#{film_id}", name:, schema_version: 1,
      payload: { user_id:, film_id:, classification: })
  end

  def initialize(...)
    raise NotImplementedError, "Construct a LibraryFilm subtype" if self.class == LibraryFilm

    super
  end
end

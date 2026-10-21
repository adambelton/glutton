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

  def can_watch?
    false
  end

  def initialize(...)
    raise NotImplementedError, "Construct a LibraryFilm subtype" if self.class == LibraryFilm

    super
  end
end

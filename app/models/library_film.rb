class LibraryFilm < ApplicationRecord
  belongs_to :user
  belongs_to :film

  validates :film_id, uniqueness: { scope: :user_id }

  def can_watch?
    false
  end

  def record_watched
    raise Library::WatchUnavailable, "Recording watched is not supported"
  end

  def initialize(...)
    raise NotImplementedError, "Construct a LibraryFilm subtype" if self.class == LibraryFilm

    super
  end
end

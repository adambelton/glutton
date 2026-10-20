class LibraryFilm < ApplicationRecord
  belongs_to :user
  belongs_to :film

  # Storage allowlist for the only implemented subtype; not behavioural dispatch.
  validates :type, inclusion: { in: [ "LibraryFilmWatched" ] }
  validates :film_id, uniqueness: { scope: :user_id }
end

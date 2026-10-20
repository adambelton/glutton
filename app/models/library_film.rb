class LibraryFilm < ApplicationRecord
  belongs_to :user
  belongs_to :film

  validates :type, inclusion: { in: [ "LibraryFilmWatched" ] }
  validates :film_id, uniqueness: { scope: :user_id }
end

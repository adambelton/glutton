class LibraryFilmWatched < LibraryFilm
  validates :watched_at, presence: true

  def library_state
    { film_id:, classification: :watched, watched_at: }
  end
end

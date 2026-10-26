class LibraryFilmWatched < LibraryFilm
  def rated?
    RatingFilm.where(user_id:, film_id:).rated.exists?
  end
end

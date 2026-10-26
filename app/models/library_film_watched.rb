class LibraryFilmWatched < LibraryFilm
  def rating_status
    rated? ? RatingStatuses::RATED : RatingStatuses::AWAITING_RATING
  end

  def can_rate?
    !rated?
  end

  def rated?
    RatingFilm.where(user_id:, film_id:).rated.exists?
  end
end

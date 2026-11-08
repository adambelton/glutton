module Library
  class LibraryFilmWatched < LibraryFilm
    def rating_status(rated: rated?)
      rated ? RatingStatuses::RATED : RatingStatuses::AWAITING_RATING
    end

    def can_rate?(rated: rated?)
      !rated
    end

    def can_edit_rating?(rated: rated?)
      rated
    end

    def rated?
      Ratings::RatingFilm.where(user_id:, film_id:).rated.exists?
    end
  end
end

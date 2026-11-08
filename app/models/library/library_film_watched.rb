module Library
  class LibraryFilmWatched < LibraryFilm
    has_one :rated_rating_film, -> { rated }, class_name: "Ratings::RatingFilm",
      primary_key: [ :user_id, :film_id ], foreign_key: [ :user_id, :film_id ]

    def rating_status
      rated? ? RatingStatuses::RATED : RatingStatuses::AWAITING_RATING
    end

    def can_rate?
      !rated?
    end

    def can_edit_rating?
      rated?
    end

    def rated?
      rating_association = association(:rated_rating_film)
      rating_association.loaded? ? rating_association.target.present? : rating_association.scope.exists?
    end
  end
end

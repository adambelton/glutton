module Library
  class ConsumeRating
    SUBSCRIBER = "library.completed_ratings".freeze

    def self.call(event:, user:)
      validate_event!(event:, user:)
      film = Film.find_by(id: event.payload.fetch("film_id"))
      raise FilmUnavailable, "Rated film is unavailable" unless film

      library_film = LibraryFilm.lock.find_by(user_id: user.id, film_id: film.id)
      if library_film.nil?
        library_film = LibraryFilmWatched.create!(user:, film:)
      elsif library_film.can_confirm_watched?
        library_film = library_film.becomes!(LibraryFilmWatched)
        library_film.save!
      else
        return :ignored
      end

      library_film.publish_event!(name: Events::FILM_MARKED_WATCHED, classification: "watched",
        correlation_id: event.correlation_id, causation_id: event.id)
      :processed
    end

    def self.validate_event!(event:, user:)
      stream = event.domain_event_stream
      payload = event.payload
      # Event payloads are a versioned external boundary, not trusted model roles.
      valid = event.schema_version == 1 && event.name == Ratings::Events::RATING_SUBMITTED &&
        stream.publisher == Ratings::EVENTS_PUBLISHING_DOMAIN &&
        payload.is_a?(Hash) &&
        %w[user_id film_id].all? { |key| payload[key].is_a?(Integer) && payload[key].positive? } &&
        payload["user_id"] == user.id && stream.user_id == user.id &&
        stream.stream_key == "film:#{payload['film_id']}"
      raise ArgumentError, "Invalid or unsupported RatingSubmitted contract" unless valid
    end
    private_class_method :validate_event!
  end
end

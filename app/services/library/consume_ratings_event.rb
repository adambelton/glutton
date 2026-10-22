module Library
  class ConsumeRatingsEvent
    SUBSCRIBER = "library.completed_ratings".freeze
    HANDLERS = {
      Ratings::Events::RATING_SUBMITTED => EventHandlers::Ratings::RatingSubmitted
    }.freeze
    EVENT_NAMES = HANDLERS.keys.freeze

    def self.call(event:, user:)
      validate_event!(event:, user:)
      film = Film.find_by(id: event.payload.fetch("film_id"))
      raise FilmUnavailable, "Rated film is unavailable" unless film

      library_film = LibraryFilm.lock.find_by(user_id: user.id, film_id: film.id)
      HANDLERS.fetch(event.name).call(event:, user:, film:, library_film:)
    end

    def self.validate_event!(event:, user:)
      stream = event.domain_event_stream
      payload = event.payload
      # Validate only the external event fields Library needs, not rating values.
      valid = event.schema_version == 1 && EVENT_NAMES.include?(event.name) &&
        stream.publisher == Ratings::EVENTS_PUBLISHING_DOMAIN && payload.is_a?(Hash) &&
        %w[user_id film_id].all? { |key| payload[key].is_a?(Integer) && payload[key].positive? } &&
        payload["user_id"] == user.id && stream.user_id == user.id &&
        stream.stream_key == "film:#{payload['film_id']}"
      raise ArgumentError, "Invalid or unsupported Ratings event contract" unless valid
    end
    private_class_method :validate_event!
  end
end

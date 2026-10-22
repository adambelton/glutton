module Ratings
  class ConsumeLibraryEvent
    SUBSCRIBER = "ratings.library_events".freeze
    HANDLERS = {
      Library::Events::FILM_MARKED_WATCHED => EventHandlers::Library::FilmMarkedWatched,
      Library::Events::FILM_MARKED_NOT_INTERESTED => EventHandlers::Library::FilmMarkedNotInterested,
      Library::Events::FILM_ADDED_TO_WATCHLIST => EventHandlers::Library::FilmAddedToWatchlist,
      Library::Events::FILM_REMOVED_FROM_WATCHLIST => EventHandlers::Library::FilmRemovedFromWatchlist
    }.freeze
    EVENT_NAMES = HANDLERS.keys.freeze

    def self.call(event:, user:)
      validate_event!(event:, user:)
      film = Film.find_by(id: event.payload.fetch("film_id"))
      raise FilmUnavailable unless film

      rating_film = RatingFilm.lock.find_by(user_id: user.id, film_id: film.id)
      HANDLERS.fetch(event.name).call(rating_film:, user:, film:)
    end

    def self.validate_event!(event:, user:)
      stream = event.domain_event_stream
      payload = event.payload
      # Validate only the external event fields Ratings needs, not Library classification.
      valid = event.schema_version == 1 && EVENT_NAMES.include?(event.name) &&
        stream.publisher == Library::EVENTS_PUBLISHING_DOMAIN && payload.is_a?(Hash) &&
        %w[user_id film_id].all? { |key| payload[key].is_a?(Integer) && payload[key].positive? } &&
        payload["user_id"] == user.id && stream.user_id == user.id &&
        stream.stream_key == "film:#{payload['film_id']}"
      raise ArgumentError, "Invalid or unsupported Library film event contract" unless valid
    end
    private_class_method :validate_event!
  end
end

module Ratings
  module EventHandlers
    class ConsumeLibraryEvent
      SUBSCRIBER = "ratings.library_events".freeze
      HANDLERS = {
        ::Library::Events::FILM_MARKED_WATCHED => Library::FilmMarkedWatched,
        ::Library::Events::FILM_MARKED_NOT_INTERESTED => Library::FilmMarkedNotInterested,
        ::Library::Events::FILM_ADDED_TO_WATCHLIST => Library::FilmAddedToWatchlist,
        ::Library::Events::FILM_REMOVED_FROM_WATCHLIST => Library::FilmRemovedFromWatchlist
      }.freeze
      EVENT_NAMES = HANDLERS.keys.freeze

      def self.call(event:, user:)
        validate_event!(event:, user:)
        film = Registry::Film.find_by(id: event.payload.fetch("film_id"))
        raise Errors::FilmUnavailable unless film

        rating_film = RatingFilm.lock.find_by(user_id: user.id, film_id: film.id)
        HANDLERS.fetch(event.name).call(rating_film:, user:, film:)
      end

      def self.validate_event!(event:, user:)
        stream = event.domain_event_stream
        payload = event.payload
        # Validate only the external event fields Ratings needs, not Library classification.
        valid = event.schema_version == 1 && EVENT_NAMES.include?(event.name) &&
          stream.publisher == ::Library::Events::PUBLISHING_DOMAIN && payload.is_a?(Hash) &&
          %w[user_id film_id].all? { |key| payload[key].is_a?(Integer) && payload[key].positive? } &&
          payload["user_id"] == user.id && stream.user_id == user.id &&
          stream.stream_key == "film:#{payload['film_id']}"
        raise ArgumentError, "Invalid or unsupported Library film event contract" unless valid
      end
      private_class_method :validate_event!
    end
  end
end

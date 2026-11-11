module Recommendations
  module EventHandlers
    class ConsumeLibraryEvent
      SUBSCRIBER = "recommendations.library_events".freeze

      HANDLERS = {
        ::Library::Events::FILM_ADDED_TO_WATCHLIST => Library::FilmAddedToWatchlist,
        ::Library::Events::FILM_MARKED_WATCHED => Library::FilmMarkedWatched,
        ::Library::Events::FILM_REMOVED_FROM_WATCHLIST => Library::FilmRemovedFromWatchlist
      }.freeze
      EVENT_NAMES = HANDLERS.keys.freeze

      def self.call(event:, user:)
        stream = event.domain_event_stream
        payload = event.payload
        handler = HANDLERS[event.name]
        valid = event.schema_version == 1 && handler.present? &&
          stream.publisher == ::Library::Events::PUBLISHING_DOMAIN && payload.is_a?(Hash) &&
          %w[user_id film_id].all? { |key| payload[key].is_a?(Integer) && payload[key].positive? } &&
          payload["user_id"] == user.id && stream.user_id == user.id &&
          stream.stream_key == "film:#{payload['film_id']}"
        raise ArgumentError, "Invalid or unsupported event for Recommendations" unless valid

        film = Registry::Film.find_by(id: payload.fetch("film_id"))
        return :ignored unless film.present?

        recommendation_film = RecommendationFilm.lock.find_or_initialize_by(user:, film:)
        handler.call(recommendation_film:)
      end
    end
  end
end

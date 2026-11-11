module Library
  module EventHandlers
    class ConsumeRatingsEvent
      SUBSCRIBER = "library.completed_ratings".freeze

      HANDLERS = {
        ::Ratings::Events::RATING_SUBMITTED => Ratings::RatingSubmitted
      }.freeze
      EVENT_NAMES = HANDLERS.keys.freeze

      def self.call(event:, user:)
        stream = event.domain_event_stream
        payload = event.payload
        handler = HANDLERS[event.name]
        valid = event.schema_version == 1 && handler.present? &&
          stream.publisher == ::Ratings::Events::PUBLISHING_DOMAIN && payload.is_a?(Hash) &&
          %w[user_id film_id].all? { |key| payload[key].is_a?(Integer) && payload[key].positive? } &&
          payload["user_id"] == user.id && stream.user_id == user.id &&
          stream.stream_key == "film:#{payload['film_id']}"
        raise ArgumentError, "Invalid or unsupported event for Library" unless valid

        handler.call(event:, user:)
      end
    end
  end
end

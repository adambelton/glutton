module Library
  module EventHandlers
    class ConsumeRecommendationsEvent
      SUBSCRIBER = "library.recommendations_events".freeze

      HANDLERS = {
        ::Recommendations::Events::RECOMMENDATION_ACCEPTED => Recommendations::RecommendationAccepted
      }.freeze
      EVENT_NAMES = HANDLERS.keys.freeze

      def self.call(event:, user:)
        stream = event.domain_event_stream
        payload = event.payload
        handler = HANDLERS[event.name]
        valid = event.schema_version == 1 && handler.present? &&
          stream.publisher == ::Recommendations::Events::PUBLISHING_DOMAIN && payload.is_a?(Hash) &&
          %w[user_id film_id].all? { |key| payload[key].is_a?(Integer) && payload[key].positive? } &&
          payload["user_id"] == user.id && stream.user_id == user.id &&
          stream.stream_key == "film:#{payload['film_id']}"
        raise ArgumentError, "Invalid or unsupported event for Library" unless valid

        source_record_id = payload["recommendation_film_id"]
        unless payload.keys.sort == %w[user_id film_id recommendation_film_id].sort && source_record_id.is_a?(Integer) && source_record_id.positive?
          raise ArgumentError, "Invalid Recommendations event payload for Library"
        end

        handler.call(event:, user:)
      end
    end
  end
end

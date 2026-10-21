module DomainEvents
  class Publish
    def self.call(user_id:, publisher:, stream_key:, name:, payload:, schema_version: 1, correlation_id: nil, causation_id: nil)
      raise ArgumentError, "Publication requires a source transaction" unless DomainEvent.connection.transaction_open?
      # Transport input must serialize as a JSON object, not an arbitrary Ruby object.
      raise ArgumentError, "Event payload must be a JSON object" unless payload.is_a?(Hash)

      json_payload = JSON.parse(JSON.generate(payload))
      event = User.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise OwnerUnavailable, "An active event owner is required" unless user&.active?

        stream = DomainEventStream.find_or_create_by!(user:, publisher:, stream_key:)
        id = SecureRandom.uuid
        stream.append!(id:, name:, payload: json_payload, schema_version:,
          correlation_id: correlation_id || id, causation_id:, occurred_at: Time.current)
      end
      ActiveRecord.after_all_transactions_commit { Wake.call }
      event
    end
  end
end

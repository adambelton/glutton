require "test_helper"
require_relative "../../support/domain_event_helpers"

class DomainEvents::DeliveryTest < ActiveSupport::TestCase
  include DomainEventHelpers

  setup { prepare_events }

  test "publication rejects unknown domains without persisting a stream or event" do
    assert_no_difference [ "DomainEventStream.count", "DomainEvent.count" ] do
      error = assert_raises(ActiveRecord::RecordInvalid) { publish(publisher: "unknown") }
      assert error.record.errors.added?(:publisher, :inclusion, value: "unknown")
    end
  end

  test "publishing domains have independent streams for the same user and film" do
    events = DomainEventStream::PublishingDomains::ALL.map { |publisher| publish(publisher:) }
    assert_equal 3, events.map(&:domain_event_stream_id).uniq.size
    assert events.all? { |event| event.sequence == 1 }
  end

  test "status exposes undiscovered backlog and failure classes without payloads" do
    event = publish(payload: { value: 1, secret: "private content" })
    consumer = subscription { raise ArgumentError, "private failure" }
    travel 10.seconds
    status = DomainEvents::Status.call(subscriptions: [ consumer ])
    assert_equal [ { subscriber: "projection", count: 1, oldest_age_seconds: 10 } ], status[:undiscovered]
    dispatch(consumer)
    receipt = delivery(event)
    receipt.update!(attempts: 10)
    receipt.record_failure!(ArgumentError.new("private failure"))
    status = DomainEvents::Status.call(subscriptions: [ consumer ])
    assert_equal 0, status[:undiscovered].first[:count]
    assert_equal [ [ receipt.id, "projection", "ArgumentError" ] ], status[:failed]
    refute_includes JSON.generate(status), "private"
  end

  test "publication retains an immutable envelope and rolls back source and sequence together" do
    first = publish
    assert_equal 1, first.sequence
    assert_equal first.id, first.correlation_id
    assert_equal({ "value" => 1 }, first.payload)
    assert_raises(ActiveRecord::ReadOnlyRecord) { first.update!(name: "Other") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { first.update_columns(payload: {}) }
    User.transaction(requires_new: true) do
      @user.touch
      publish
      raise ActiveRecord::Rollback
    end
    assert_equal 1, DomainEvent.count
    second = publish(correlation_id: first.correlation_id, causation_id: first.id)
    assert_equal 2, second.sequence
    assert_equal first.id, second.causation_id
    assert_equal first.correlation_id, second.correlation_id
    assert_equal first.domain_event_stream_id, second.domain_event_stream_id
  end

  test "failed publication rolls back sequence even when the caller rescues it" do
    first = publish
    assert_raises(ActiveRecord::StatementInvalid) { publish(schema_version: 0) }
    assert_equal 2, publish.sequence
    assert_equal first.domain_event_stream_id, publish.domain_event_stream_id
    assert_raises(ArgumentError) { publish(payload: []) }
    assert_raises(DomainEvents::OwnerUnavailable) { publish(user_id: nil) }
    travel UserGuest::EXPIRY_DURATION do
      assert_raises(DomainEvents::OwnerUnavailable) { publish }
    end
  end

  test "events wait for later subscriptions and processing records exactly one effect" do
    event = publish
    assert_empty dispatch
    assert_equal 0, EventDelivery.count
    assert_equal({ processed: 1 }, dispatch(subscription))
    assert_equal 1, EventEffect.count
    assert_equal event.id, EventEffect.first.event_id
    assert_equal "processed", delivery(event).status
    assert_empty dispatch(subscription)
    assert_equal :not_due, DomainEvents::Deliver.call(delivery_id: delivery(event).id, subscription: subscription)
    assert_equal 1, EventEffect.count
    assert_equal({ processed: 1 }, dispatch(subscription(name: "later")))
    assert_equal 2, EventEffect.count
  end

  test "handler writes roll back and subscribers retry independently without exposing payload errors" do
    event = publish
    failing = subscription do |event:, user:|
      EventEffect.create!(event_id: event.id, subscriber: "bad", value: 9)
      raise "private payload and credential text"
    end
    assert_equal({ retrying: 1, processed: 1 }, dispatch(failing, subscription(name: "healthy")))
    assert_equal [ "healthy" ], EventEffect.pluck(:subscriber)
    failed = delivery(event)
    assert_equal "RuntimeError", failed.last_error_class
    assert_equal 1, failed.attempts
    assert_equal 5.seconds.from_now, failed.next_attempt_at
    assert_empty dispatch(subscription)
    travel 5.seconds
    assert_equal({ processed: 1 }, dispatch(subscription))
    assert_equal 2, EventEffect.count
    assert_nil failed.reload.last_error_class
    assert_equal 2, failed.attempts
  end

  test "a blocked predecessor cannot be overtaken while unrelated streams advance" do
    first = publish
    second = publish
    other = publish(stream_key: "film:2")
    failing = subscription do |event:, user:|
      raise "failure" if event.id == first.id
      EventEffect.create!(event_id: event.id, subscriber: "projection", value: 1)
      :processed
    end
    assert_equal({ retrying: 1, processed: 1 }, dispatch(failing))
    assert_equal [ other.id ], EventEffect.pluck(:event_id)
    assert_equal :blocked, DomainEvents::Deliver.call(delivery_id: delivery(second).id, subscription: subscription)
    travel 5.seconds
    assert_equal({ processed: 1 }, dispatch(subscription))
    assert_equal({ processed: 1 }, dispatch(subscription))
    assert_equal [ other.id, first.id, second.id ], EventEffect.order(:id).pluck(:event_id)
  end

  test "missing receipts also block successors and unsubscribed event names do not block" do
    first = publish
    publish(name: "Unrelated")
    second = publish
    receipt = EventDelivery.create!(domain_event: second, subscriber: "projection", next_attempt_at: Time.current)
    assert_equal :blocked, DomainEvents::Deliver.call(delivery_id: receipt.id, subscription: subscription)
    dispatch(subscription)
    dispatch(subscription)
    assert_equal [ first.id, second.id ], EventEffect.order(:id).pluck(:event_id)
  end

  test "terminal failures require explicit retry and cannot reset completed work" do
    event = publish
    failing = subscription { |event:, user:| raise "failure" }
    10.times do |index|
      assert_equal({ index == 9 ? :failed : :retrying => 1 }, dispatch(failing))
      travel_to delivery(event).next_attempt_at
    end
    assert_equal "failed", delivery(event).status
    assert_empty dispatch(subscription)
    delivery(event).with_lock { delivery(event).retry! }
    assert_equal({ processed: 1 }, dispatch(subscription))
    assert_raises(DomainEvents::RetryUnavailable) { delivery(event).retry! }
    assert_equal 1, EventEffect.count
  end

  test "ignored is a successful receipt but an invalid result or explicit rollback is retried" do
    event = publish
    assert_equal({ ignored: 1 }, dispatch(subscription(name: "ignored") { |event:, user:| :ignored }))
    assert_equal({ retrying: 1 }, dispatch(subscription(name: "invalid") { |event:, user:| nil }))
    assert_equal({ retrying: 1 }, dispatch(subscription(name: "rollback") { |event:, user:| raise ActiveRecord::Rollback }))
    assert_equal 0, EventEffect.count
    assert_equal "ignored", delivery(event, subscriber: "ignored").status
  end

  test "expired and deleted owners skip handlers and physical cleanup cascades payloads" do
    expired_event = publish
    deleted = UserDeleted.create!
    other = UserGuest.create!
    other_event = publish(user_id: other.id)
    # The stored owner can change after publication; consumption must re-read it.
    other.update_columns(type: "UserDeleted")
    travel UserGuest::EXPIRY_DURATION
    assert_equal({ skipped: 2 }, dispatch(subscription))
    assert_equal 0, EventEffect.count
    assert_equal "skipped", delivery(other_event).status
    assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    assert_not DomainEvent.exists?(expired_event.id)
    assert_not EventDelivery.exists?(domain_event_id: expired_event.id)
    assert DomainEvent.exists?(other_event.id)
    assert User.exists?(deleted.id)
  end

  test "claim preserves owner and events beyond the guest deadline" do
    event = publish
    pending = Identity::PrepareRegistration.call(email_address: "events@example.test", guest_user_id: @user.id,
      password: "a long password phrase", password_confirmation: "a long password phrase")
    token = Identity::RegistrationConfirmation.token_for(pending_registration_id: pending.id)
    Identity::CompleteRegistration.call(token:)
    travel UserGuest::EXPIRY_DURATION
    assert_equal 0, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    assert_equal({ processed: 1 }, dispatch(subscription))
    assert_equal @user.id, event.domain_event_stream.user_id
  end

  test "storage enforces one receipt and sequence and object payload" do
    event = publish
    dispatch(subscription)
    assert_raises(ActiveRecord::RecordNotUnique) do
      EventDelivery.transaction(requires_new: true) do
        EventDelivery.create!(domain_event: event, subscriber: "projection", next_attempt_at: Time.current)
      end
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      DomainEvent.transaction(requires_new: true) do
        DomainEvent.insert_all!([ event.attributes.except("id").merge("id" => SecureRandom.uuid) ])
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      DomainEvent.transaction(requires_new: true) do
        DomainEvent.insert_all!([ event.attributes.except("id").merge("id" => SecureRandom.uuid, "sequence" => 2, "payload" => []) ])
      end
    end
  end
end

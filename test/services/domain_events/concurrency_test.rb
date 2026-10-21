require "test_helper"
require "timeout"
require_relative "../../support/domain_event_helpers"

class DomainEvents::ConcurrencyTest < ActiveSupport::TestCase
  include DomainEventHelpers
  self.use_transactional_tests = false

  setup do
    prepare_events
    @threads = []
    @old_adapter = DispatchDomainEventsJob.queue_adapter
    DispatchDomainEventsJob.queue_adapter = :test
  end

  teardown do
    @threads.each { |thread| thread.kill if thread.alive?; thread.join }
    User.where(id: @user.id).delete_all
    EventEffect.connection.drop_table(:event_effects)
    DispatchDomainEventsJob.queue_adapter = @old_adapter
  end

  def blocked(&operation)
    ready = Queue.new
    thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        ready << connection.select_value("SELECT pg_backend_pid()")
        operation.call
      end
    end
    @threads << thread
    pid = Timeout.timeout(5) { ready.pop }
    Timeout.timeout(5) do
      until User.connection.uncached { User.connection.select_value("SELECT cardinality(pg_blocking_pids(#{pid}))") }.positive?
        sleep 0.01
      end
    end
    thread
  end

  test "publication requires a transaction and concurrent appends retain consecutive versions" do
    assert_raises(ArgumentError) do
      DomainEvents::Publish.call(user_id: @user.id, publisher: "test_domain", stream_key: "film:1", name: "Changed", payload: {})
    end
    contender = first = nil
    User.transaction do
      first = publish
      contender = blocked { publish }
    end
    second = Timeout.timeout(5) { contender.value }
    assert_equal [ 1, 2 ], [ first.sequence, second.sequence ]
    assert_equal first.domain_event_stream_id, second.domain_event_stream_id
    assert_equal 1, DomainEventStream.where(user: @user).count
  end

  test "two workers commit one effect and receipt" do
    event = publish
    receipt = EventDelivery.create!(domain_event: event, subscriber: "projection", next_attempt_at: Time.current)
    contender = nil
    User.transaction do
      @user.lock!
      contender = blocked { DomainEvents::Deliver.call(delivery_id: receipt.id, subscription: subscription) }
      assert_equal :processed, DomainEvents::Deliver.call(delivery_id: receipt.id, subscription: subscription)
    end
    assert_equal :not_due, Timeout.timeout(5) { contender.value }
    assert_equal 1, EventEffect.count
    assert_equal 1, receipt.reload.attempts
  end

  test "a process interruption rolls back the effect and leaves pending work retryable" do
    event = publish
    receipt = EventDelivery.create!(domain_event: event, subscriber: "projection", next_attempt_at: Time.current)
    interruption = Class.new(Exception)
    interrupted = subscription do |event:, user:|
      EventEffect.create!(event_id: event.id, subscriber: "projection", value: 1)
      raise interruption
    end
    assert_raises(interruption) { DomainEvents::Deliver.call(delivery_id: receipt.id, subscription: interrupted) }
    assert_equal 0, EventEffect.count
    assert_equal "pending", receipt.reload.status
    assert_equal 0, receipt.attempts
    assert_equal :processed, DomainEvents::Deliver.call(delivery_id: receipt.id, subscription: subscription)
    assert_equal 1, EventEffect.count
  end

  test "cleanup winning before receipt insertion leaves no delivery or effect" do
    event = publish
    travel UserGuest::EXPIRY_DURATION
    contender = nil
    User.transaction do
      @user.lock!
      contender = blocked { dispatch(subscription) }
      assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    end
    assert_empty Timeout.timeout(5) { contender.value }
    assert_equal 0, EventDelivery.count
    assert_equal 0, EventEffect.count
    assert_not DomainEvent.exists?(event.id)
  end

  test "cleanup winning before delivery prevents resurrection" do
    event = publish
    receipt = EventDelivery.create!(domain_event: event, subscriber: "projection", next_attempt_at: Time.current)
    travel UserGuest::EXPIRY_DURATION
    contender = nil
    User.transaction do
      @user.lock!
      contender = blocked { DomainEvents::Deliver.call(delivery_id: receipt.id, subscription: subscription) }
      assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
    end
    assert_equal :missing, Timeout.timeout(5) { contender.value }
    assert_equal 0, EventEffect.count
    assert_not DomainEvent.exists?(event.id)
  end
end

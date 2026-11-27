require "test_helper"
require "timeout"
require_relative "../../../support/domain_event_helpers"

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
    Identity::User.where(id: @user.id).delete_all
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
      until Identity::User.connection.uncached { Identity::User.connection.select_value("SELECT cardinality(pg_blocking_pids(#{pid}))") }.positive?
        sleep 0.01
      end
    end
    thread
  end

  test "publication requires a transaction and concurrent appends retain consecutive versions" do
    assert_raises(ArgumentError) do
      DomainEvents::Publication::Publish.call(user_id: @user.id, publisher: "test_domain", stream_key: "film:1", name: "Changed", payload: {})
    end
    contender = first = nil
    Identity::User.transaction do
      first = publish
      contender = blocked { publish }
    end
    second = Timeout.timeout(5) { contender.value }
    assert_equal [ 1, 2 ], [ first.sequence, second.sequence ]
    assert_equal first.domain_event_stream_id, second.domain_event_stream_id
    assert_equal 1, DomainEvents::DomainEventStream.where(user: @user).count
  end

  test "recommendation acceptance wakes the dispatcher after the outer commit" do
    film = Registry::Film.create!(title: "Committed recommendation")
    wake_jobs = -> { DispatchDomainEventsJob.queue_adapter.enqueued_jobs.count }
    recommendation = nil

    assert_difference wake_jobs, 1 do
      Recommendations::RecommendationFilm.transaction do
        assert_no_difference wake_jobs do
          recommendation = Recommendations::RecordFilmResponse.call(user_id: @user.id, film_id: film.id, response: "accepted")
          assert_equal "accepted", recommendation.reload.response
          assert DomainEvents::DomainEvent.exists?(name: "RecommendationAccepted")
        end
      end
    end
    assert_equal "accepted", recommendation.reload.response
  ensure
    recommendation&.destroy!
    film&.destroy!
  end

  test "rolling back recommendation acceptance also rolls back publication and its wake" do
    film = Registry::Film.create!(title: "Rolled back recommendation")
    recommendation = Recommendations::RecommendationFilm.create!(user: @user, film:, recommended_at: Time.current)
    wake_jobs = -> { DispatchDomainEventsJob.queue_adapter.enqueued_jobs.count }

    assert_no_difference [ wake_jobs, -> { DomainEvents::DomainEvent.count }, -> { DomainEvents::DomainEventStream.count } ] do
      Recommendations::RecommendationFilm.transaction do
        Recommendations::RecordFilmResponse.call(user_id: @user.id, film_id: film.id, response: "accepted")
        assert_equal "accepted", recommendation.reload.response
        assert DomainEvents::DomainEvent.exists?(name: "RecommendationAccepted")
        raise ActiveRecord::Rollback
      end
    end
    assert_nil recommendation.reload.response
  ensure
    recommendation&.destroy!
    film&.destroy!
  end

  test "committed publication and delivery logs share the event correlation ID without exposing its payload" do
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output)
    Rails.logger.broadcast_to(logger)

    event = publish(payload: { value: 1, note: "private sample text" })
    dispatch(subscription)

    entries = output.string.lines.filter_map do |line|
      JSON.parse(line) if line.start_with?('{"message":"domain_event_')
    end
    publication, delivery = entries
    assert_equal "domain_event_published", publication.fetch("message")
    assert_equal "domain_event_delivery", delivery.fetch("message")
    assert_equal [ event.correlation_id, event.correlation_id ], entries.map { |entry| entry.fetch("correlation_id") }
    assert_equal "processed", delivery.fetch("outcome")
    refute_includes entries.to_json, "private sample text"
  ensure
    Rails.logger.stop_broadcasting_to(logger)
  end

  test "two workers commit one effect and receipt" do
    event = publish
    receipt = DomainEvents::EventDelivery.create!(domain_event: event, subscriber: "projection", next_attempt_at: Time.current)
    contender = nil
    Identity::User.transaction do
      @user.lock!
      contender = blocked { DomainEvents::Delivery::Deliver.call(delivery_id: receipt.id, subscription: subscription) }
      assert_equal :processed, DomainEvents::Delivery::Deliver.call(delivery_id: receipt.id, subscription: subscription)
    end
    assert_equal :not_due, Timeout.timeout(5) { contender.value }
    assert_equal 1, EventEffect.count
    assert_equal 1, receipt.reload.attempts
  end

  test "a process interruption rolls back the effect and leaves pending work retryable" do
    event = publish
    receipt = DomainEvents::EventDelivery.create!(domain_event: event, subscriber: "projection", next_attempt_at: Time.current)
    interruption = Class.new(Exception)
    interrupted = subscription do |event:, user:|
      EventEffect.create!(event_id: event.id, subscriber: "projection", value: 1)
      raise interruption
    end
    assert_raises(interruption) { DomainEvents::Delivery::Deliver.call(delivery_id: receipt.id, subscription: interrupted) }
    assert_equal 0, EventEffect.count
    assert_equal DomainEvents::EventDelivery::Statuses::PENDING, receipt.reload.status
    assert_equal 0, receipt.attempts
    assert_equal :processed, DomainEvents::Delivery::Deliver.call(delivery_id: receipt.id, subscription: subscription)
    assert_equal 1, EventEffect.count
  end

  test "cleanup winning before receipt insertion leaves no delivery or effect" do
    event = publish
    travel Identity::UserGuest::EXPIRY_DURATION
    contender = nil
    Identity::User.transaction do
      @user.lock!
      contender = blocked { dispatch(subscription) }
      assert_equal 1, Identity::AccountAdministration::CleanupExpiredAccounts.call[:guests_deleted]
    end
    assert_empty Timeout.timeout(5) { contender.value }
    assert_equal 0, DomainEvents::EventDelivery.count
    assert_equal 0, EventEffect.count
    assert_not DomainEvents::DomainEvent.exists?(event.id)
  end

  test "cleanup winning before delivery prevents resurrection" do
    event = publish
    receipt = DomainEvents::EventDelivery.create!(domain_event: event, subscriber: "projection", next_attempt_at: Time.current)
    travel Identity::UserGuest::EXPIRY_DURATION
    contender = nil
    Identity::User.transaction do
      @user.lock!
      contender = blocked { DomainEvents::Delivery::Deliver.call(delivery_id: receipt.id, subscription: subscription) }
      assert_equal 1, Identity::AccountAdministration::CleanupExpiredAccounts.call[:guests_deleted]
    end
    assert_equal :missing, Timeout.timeout(5) { contender.value }
    assert_equal 0, EventEffect.count
    assert_not DomainEvents::DomainEvent.exists?(event.id)
  end

  test "cleanup during delivery discovery leaves other events deliverable" do
    event = publish
    receipt = DomainEvents::EventDelivery.create!(domain_event: event, subscriber: "projection", next_attempt_at: Time.current)
    travel Identity::UserGuest::EXPIRY_DURATION
    active_user = Identity::UserGuest.create!
    surviving_event = publish(user_id: active_user.id)
    cleaned = false
    cleanup_after_discovery = lambda do |*args|
      next if cleaned || !args.last.fetch(:sql).include?('FROM "event_deliveries"')

      cleaned = true
      assert_equal 1, Identity::AccountAdministration::CleanupExpiredAccounts.call[:guests_deleted]
    end

    ActiveSupport::Notifications.subscribed(cleanup_after_discovery, "sql.active_record") do
      assert_equal :missing, DomainEvents::Delivery::Deliver.call(delivery_id: receipt.id, subscription: subscription)
    end
    assert cleaned
    assert_equal({ processed: 1 }, dispatch(subscription))
    assert_equal surviving_event.id, EventEffect.sole.event_id
  ensure
    Identity::User.where(id: active_user.id).delete_all if active_user.present?
  end
end

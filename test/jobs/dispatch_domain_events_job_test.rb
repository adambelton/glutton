require "test_helper"
require "open3"
require "timeout"
require_relative "../support/domain_event_helpers"

class DispatchDomainEventsJobTest < ActiveSupport::TestCase
  include DomainEventHelpers
  self.use_transactional_tests = false

  setup do
    prepare_events
    @old_adapter = DispatchDomainEventsJob.queue_adapter
    DispatchDomainEventsJob.queue_adapter = GoodJob::Adapter.new(execution_mode: :external)
    @old_subscriptions = DomainEvents::Subscriptions.method(:all)
    registrations = [ subscription ]
    DomainEvents::Subscriptions.define_singleton_method(:all) { registrations }
    @job_ids = GoodJob::Job.pluck(:id)
  end

  teardown do
    DomainEvents::Subscriptions.define_singleton_method(:all, @old_subscriptions)
    DispatchDomainEventsJob.queue_adapter = @old_adapter
    User.where(id: @user.id).delete_all
    EventEffect.connection.drop_table(:event_effects)
    jobs = GoodJob::Job.where.not(id: @job_ids)
    GoodJob::Execution.where(active_job_id: jobs.select(:active_job_id)).delete_all
    jobs.delete_all
  end

  test "after-commit wakeup creates a durable job and GoodJob delivers committed events" do
    event = nil
    before = GoodJob::Job.count
    User.transaction do
      event = publish
      assert_equal before, GoodJob::Job.count
    end
    assert_equal before + 1, GoodJob::Job.count
    job = GoodJob::Job.order(:created_at).last
    assert_equal "DispatchDomainEventsJob", job.job_class
    assert_equal [], job.serialized_params.fetch("arguments")
    GoodJob.perform_inline("domain_events", limit: 5)
    assert job.reload.finished_at
    assert_equal [ event.id ], EventEffect.pluck(:event_id)
    assert_equal EventDelivery::Statuses::PROCESSED, delivery(event).status
  end

  test "source rollback produces neither an event nor a wakeup job" do
    assert_no_difference [ "DomainEvent.count", "GoodJob::Job.count" ] do
      User.transaction do
        publish
        raise ActiveRecord::Rollback
      end
    end
  end

  test "a failed wakeup does not undo publication and a later sweep recovers it" do
    adapter = Object.new
    def adapter.enqueue(job)
      raise "private enqueue error"
    end
    def adapter.enqueue_at(job, timestamp)
      enqueue(job)
    end
    DispatchDomainEventsJob.queue_adapter = adapter
    event = publish
    assert DomainEvent.exists?(event.id)
    assert_equal 0, EventEffect.count
    DispatchDomainEventsJob.queue_adapter = GoodJob::Adapter.new(execution_mode: :external)
    DispatchDomainEventsJob.perform_later
    GoodJob.perform_inline("domain_events", limit: 5)
    assert_equal [ event.id ], EventEffect.pluck(:event_id)
  end

  test "GoodJob recovers a killed worker without duplicating handler effects" do
    # The child uses the real clock; do not leave its receipt in the parent's future.
    travel_back
    event = publish
    script = <<~RUBY_SCRIPT
      require Rails.root.join("test/support/domain_event_helpers")
      handler = ->(event:, user:) do
        EventEffect.create!(event_id: event.id, subscriber: "projection", value: 1)
        Process.kill("KILL", Process.pid)
      end
      registration = DomainEvents::Subscription.new(name: "projection", publisher: "test_domain", event_names: ["Changed"], handler:)
      DomainEvents::Subscriptions.define_singleton_method(:all) { [registration] }
      GoodJob.perform_inline("domain_events", limit: 1)
    RUBY_SCRIPT
    # Use the current test worker database when Rails tests run in parallel.
    database = ActiveRecord::Base.connection_db_config.database
    env = { "RAILS_ENV" => "test", "PGDATABASE" => database }
    command = "ActiveRecord::Base.establish_connection(ActiveRecord::Base.connection_db_config.configuration_hash.merge(database: ENV.fetch('PGDATABASE'))); #{script}"
    status = nil
    Open3.popen2e(env, RbConfig.ruby, "bin/rails", "runner", command) do |input, output, wait|
      input.close
      Timeout.timeout(20) do
        output.read
        status = wait.value
      end
    ensure
      Process.kill("KILL", wait.pid) if wait&.alive?
    end
    assert status.signaled?
    assert_equal Signal.list.fetch("KILL"), status.termsig
    assert_equal 0, EventEffect.count
    assert_equal EventDelivery::Statuses::PENDING, delivery(event).status
    GoodJob.perform_inline("domain_events", limit: 5)
    assert_equal [ event.id ], EventEffect.pluck(:event_id)
    assert_equal EventDelivery::Statuses::PROCESSED, delivery(event).status
  end
end

require "test_helper"
require "timeout"

module Identity
  class PrepareRegistrationConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    test "same guest preparations serialize across separate connections" do
      guest = GuestUser.create!
      ready = Queue.new
      thread = nil
      first = nil
      PendingRegistration.transaction do
        User.lock.find(guest.id)
        thread = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            PrepareRegistration.call(guest_user_id: guest.id, email_address: "second@example.test",
              password: "second password phrase", password_confirmation: "second password phrase")
          end
        end
        pid = Timeout.timeout(5) { ready.pop }
        connection = ActiveRecord::Base.connection
        Timeout.timeout(5) do
          until connection.uncached { connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)}))") }.positive?
            sleep 0.01
          end
        end
        first = PrepareRegistration.call(guest_user_id: guest.id, email_address: "first@example.test",
          password: "first password phrase", password_confirmation: "first password phrase")
      end
      second = Timeout.timeout(5) { thread.value }
      assert_not PendingRegistration.exists?(first.id)
      assert_equal 1, PendingRegistration.where(guest_user_id: guest.id).count
      assert_equal "second@example.test", second.reload.email_address
      assert second.authenticate("second password phrase")
      assert_nil guest.reload.email_address
    ensure
      thread&.kill if thread&.alive?
      thread&.join
      guest&.delete if guest&.persisted?
    end
  end
end

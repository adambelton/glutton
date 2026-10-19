require "test_helper"

module Identity
  class PrepareRegistrationTest < ActiveSupport::TestCase
    def prepare(**attributes)
      PrepareRegistration.call(email_address: "reader@example.test", password: "a long password phrase",
        password_confirmation: "a long password phrase", **attributes)
    end

    test "direct signup creates only an independent pending request" do
      assert_no_difference [ "User.count", "Session.count", "ActionMailer::Base.deliveries.count" ] do
        assert_difference "PendingRegistration.count", 2 do
          first = prepare
          second = prepare
          refute_equal first.id, second.id
          assert_nil first.guest_user_id
          assert_nil second.guest_user_id
        end
      end
    end

    test "guest preparation and replacement retain guest state and revoke old request identity" do
      guest = GuestUser.create!
      session = Session.create!(user: guest)
      before = guest.attributes
      session_before = session.attributes
      first = prepare(guest_user_id: guest.id)
      assert_equal guest.id, first.guest_user_id
      assert_no_difference [ "User.count", "Session.count", "PendingRegistration.count" ] do
        replacement = prepare(guest_user_id: guest.id, email_address: " NEW@Example.test ",
          password: "a replacement password", password_confirmation: "a replacement password")
        assert_equal "new@example.test", replacement.email_address
        assert replacement.authenticate("a replacement password")
        assert_not replacement.authenticate("a long password phrase")
        assert_not PendingRegistration.exists?(first.id)
      end
      assert_equal before, guest.reload.attributes
      assert_equal session_before, session.reload.attributes
      assert session.active?
    end

    test "every invalid replacement rolls back to previous credentials" do
      guest = GuestUser.create!
      first = prepare(guest_user_id: guest.id)
      before = first.attributes
      [ { password: nil }, { password: "" }, { password: "short" }, { password_confirmation: nil },
        { password_confirmation: "mismatch" }, { email_address: "invalid" } ].each do |attributes|
        error = assert_raises(ActiveRecord::RecordInvalid) { prepare(guest_user_id: guest.id, **attributes) }
        assert_instance_of PendingRegistration, error.record
        assert error.record.errors.any?
        assert_equal before, first.reload.attributes
        assert_equal 1, PendingRegistration.where(guest_user_id: guest.id).count
      end
    end

    test "a database failure after deleting the prior request rolls back replacement" do
      guest = GuestUser.create!
      first = prepare(guest_user_id: guest.id)
      before = first.attributes
      PendingRegistration.connection.execute("ALTER TABLE pending_registrations ADD CONSTRAINT test_replacement_failure CHECK (email_address <> 'fail@example.test')")
      assert_raises(ActiveRecord::StatementInvalid) do
        prepare(guest_user_id: guest.id, email_address: "fail@example.test")
      end
      assert_equal before, first.reload.attributes
      assert_equal 1, PendingRegistration.where(guest_user_id: guest.id).count
    end

    test "missing registered deleted and expired guests cannot prepare" do
      registered = RegisteredUser.create!(email_address: "registered@example.test", password: "a long password phrase",
        password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
      deleted = DeletedUser.create!
      guest = freeze_time { GuestUser.create! }
      travel_to guest.created_at + 24.hours - 1.second do
        assert prepare(guest_user_id: guest.id).persisted?
      end
      travel_to guest.created_at + 24.hours do
        assert_no_difference [ "PendingRegistration.count", "User.count", "Session.count" ] do
          [ -1, registered.id, deleted.id, guest.id ].each do |id|
            assert_raises(RegistrationUnavailable) { prepare(guest_user_id: id) }
          end
        end
      end
      assert_nil guest.reload.email_address
    end

    test "stored lifecycle wins over a cached guest and pending email never selects a user" do
      cached = GuestUser.create!
      cached.update_columns(type: "DeletedUser")
      assert_instance_of GuestUser, cached
      assert_raises(RegistrationUnavailable) { prepare(guest_user_id: cached.id) }
      registered = RegisteredUser.create!(email_address: "reader@example.test", password: "registered password",
        password_confirmation: "registered password", email_confirmed_at: Time.current)
      guest = GuestUser.create!
      pending = prepare(guest_user_id: guest.id)
      direct = prepare
      assert_equal guest.id, pending.guest_user_id
      assert_nil direct.guest_user_id
      assert_equal registered, RegisteredUser.find_by_email(pending.email_address)
      assert_nil Authenticate.call(email_address: pending.email_address, password: "a long password phrase")
      assert_nil guest.reload.email_address
    end
  end
end

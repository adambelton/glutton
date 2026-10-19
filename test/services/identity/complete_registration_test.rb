require "test_helper"
require "stringio"

module Identity
  class CompleteRegistrationTest < ActiveSupport::TestCase
    def prepare(**attributes)
      PrepareRegistration.call(email_address: "reader@example.test", password: "a long password phrase",
        password_confirmation: "a long password phrase", **attributes)
    end

    def token_for(record)
      RegistrationConfirmation.token_for(pending_registration_id: record.id)
    end

    test "direct confirmation creates a confirmed account fresh session and consumes pending" do
      freeze_time do
        record = prepare(email_address: " Reader@Example.TEST ")
        digest = record.password_digest
        token = token_for(record)
        session = nil
        assert_difference [ "RegisteredUser.count", "Session.count" ], 1 do
          assert_difference "PendingRegistration.count", -1 do
            session = CompleteRegistration.call(token:)
          end
        end
        user = session.user
        assert session.active?
        assert_instance_of RegisteredUser, user
        assert_equal "reader@example.test", user.email_address
        assert_equal digest, user.password_digest
        assert_equal Time.current, user.email_confirmed_at
        assert user.authenticate("a long password phrase")
        assert_raises(RegistrationUnavailable) { CompleteRegistration.call(token:) }
      end
    end

    test "guest confirmation retains identity and revokes every preconfirmation session" do
      guest = GuestUser.create!
      old_sessions = 2.times.map { Session.create!(user: guest) }
      created_at = guest.created_at
      record = prepare(guest_user_id: guest.id)
      digest = record.password_digest
      token = token_for(record)
      session = nil
      assert_no_difference "User.count" do
        session = CompleteRegistration.call(token:)
      end
      user = User.find(guest.id)
      assert_instance_of RegisteredUser, user
      assert_equal created_at, user.created_at
      assert_equal digest, user.password_digest
      assert_equal user, session.user
      assert session.active?
      assert_equal [ session.id ], Session.where(user_id: guest.id).pluck(:id)
      old_sessions.each { |old| assert_not old.active? }
      assert_not PendingRegistration.exists?(record.id)
    end

    test "malformed tokens and unavailable guests leave all state unchanged" do
      [ nil, "", "garbage", [], "tampered--signature", "\xFF".b ].each do |token|
        assert_no_difference [ "User.count", "Session.count", "PendingRegistration.count" ] do
          assert_raises(RegistrationUnavailable) { CompleteRegistration.call(token:) }
        end
      end
      guest = GuestUser.create!
      record = prepare(guest_user_id: guest.id)
      token = token_for(record)
      guest.update_columns(type: "DeletedUser")
      assert_raises(RegistrationUnavailable) { CompleteRegistration.call(token:) }
      assert PendingRegistration.exists?(record.id)
      assert_instance_of DeletedUser, User.find(guest.id)
    end

    test "email conflict never authenticates or changes the existing account" do
      existing = RegisteredUser.create!(email_address: "reader@example.test", password: "existing password phrase",
        password_confirmation: "existing password phrase", email_confirmed_at: Time.current)
      existing_attributes = existing.attributes
      record = prepare
      error = nil
      assert_no_difference [ "User.count", "Session.count", "PendingRegistration.count" ] do
        error = assert_raises(RegistrationUnavailable) { CompleteRegistration.call(token: token_for(record)) }
      end
      assert_nil error.cause
      assert_equal existing_attributes, existing.reload.attributes
      assert PendingRegistration.exists?(record.id)
    end

    test "failure at each mutation stage rolls back the entire guest completion" do
      guest = GuestUser.create!
      Session.create!(user: guest)
      record = prepare(guest_user_id: guest.id)
      token = token_for(record)
      user_before = guest.attributes
      pending_before = record.attributes
      sessions_before = Session.where(user_id: guest.id).map(&:attributes)
      [ /UPDATE "users"/, /DELETE FROM "sessions"/, /INSERT INTO "sessions"/, /DELETE FROM "pending_registrations"/ ].each do |pattern|
        listener = ->(event) { raise IOError, "simulated persistence failure" if event.payload[:sql].match?(pattern) }
        assert_raises(IOError) do
          ActiveSupport::Notifications.subscribed(listener, "sql.active_record") do
            CompleteRegistration.call(token:)
          end
        end
        assert_equal user_before, User.find(guest.id).attributes
        assert_equal pending_before, PendingRegistration.find(record.id).attributes
        assert_equal sessions_before, Session.where(user_id: guest.id).map(&:attributes)
      end
      assert CompleteRegistration.call(token:).active?
    end

    test "token and credential markers stay out of logs and expected errors" do
      record = prepare
      token = token_for(record)
      output = StringIO.new
      original_logger = ActiveRecord::Base.logger
      ActiveRecord::Base.logger = ActiveSupport::Logger.new(output)
      CompleteRegistration.call(token:)
      error = assert_raises(RegistrationUnavailable) { CompleteRegistration.call(token:) }
      [ output.string, error.full_message, record.inspect ].each do |text|
        [ token, record.email_address, record.password_digest, "a long password phrase" ].each { |marker| refute_includes text, marker }
      end
    ensure
      ActiveRecord::Base.logger = original_logger
    end
  end
end

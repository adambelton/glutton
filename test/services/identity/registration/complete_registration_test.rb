require "test_helper"
require "stringio"

module Identity
  class CompleteRegistrationTest < ActiveSupport::TestCase
    def prepare(**attributes)
      Registration::PrepareRegistration.call(email_address: "reader@example.test", password: "a long password phrase",
        password_confirmation: "a long password phrase", **attributes)
    end

    def token_for(record)
      Registration::RegistrationConfirmation.token_for(pending_registration_id: record.id)
    end

    test "direct confirmation creates a confirmed account fresh session and consumes pending" do
      freeze_time do
        record = prepare(email_address: " Reader@Example.TEST ")
        digest = record.password_digest
        token = token_for(record)
        session = nil
        assert_difference [ "Identity::UserRegistered.count", "Identity::Session.count" ], 1 do
          assert_difference "Identity::PendingRegistration.count", -1 do
            session = Registration::CompleteRegistration.call(token:)
          end
        end
        user = session.user
        assert session.active?
        assert (user).can_reset_password?
        assert_equal "reader@example.test", user.email_address
        assert_equal digest, user.password_digest
        assert_equal Time.current, user.email_confirmed_at
        assert user.authenticate("a long password phrase")
        assert_raises(Errors::RegistrationUnavailable) { Registration::CompleteRegistration.call(token:) }
      end
    end

    test "guest confirmation retains identity and revokes every preconfirmation session" do
      guest = Identity::UserGuest.create!
      old_sessions = 2.times.map { Identity::Session.create!(user: guest) }
      created_at = guest.created_at
      record = prepare(guest_user_id: guest.id)
      digest = record.password_digest
      token = token_for(record)
      session = nil
      assert_no_difference "Identity::User.count" do
        session = Registration::CompleteRegistration.call(token:)
      end
      user = Identity::User.find(guest.id)
      assert (user).can_reset_password?
      assert_equal created_at, user.created_at
      assert_equal digest, user.password_digest
      assert_equal user, session.user
      assert session.active?
      assert_equal [ session.id ], Identity::Session.where(user_id: guest.id).pluck(:id)
      old_sessions.each { |old| assert_not old.active? }
      assert_not Identity::PendingRegistration.exists?(record.id)
    end

    test "malformed tokens and unavailable guests leave all state unchanged" do
      [ nil, "", "garbage", [], "tampered--signature", "\xFF".b ].each do |token|
        assert_no_difference [ "Identity::User.count", "Identity::Session.count", "Identity::PendingRegistration.count" ] do
          assert_raises(Errors::RegistrationUnavailable) { Registration::CompleteRegistration.call(token:) }
        end
      end
      guest = Identity::UserGuest.create!
      record = prepare(guest_user_id: guest.id)
      token = token_for(record)
      guest.update_columns(type: "UserDeleted")
      assert_raises(Errors::RegistrationUnavailable) { Registration::CompleteRegistration.call(token:) }
      assert Identity::PendingRegistration.exists?(record.id)
      assert_not (Identity::User.find(guest.id)).active?
    end

    test "email conflict never authenticates or changes the existing account" do
      record = prepare
      existing = Identity::UserRegistered.create!(email_address: "reader@example.test", password: "existing password phrase",
        password_confirmation: "existing password phrase", email_confirmed_at: Time.current)
      existing_attributes = existing.slice(:id, :email_address, :password_digest, :email_confirmed_at)
      error = nil
      assert_no_difference [ "Identity::User.count", "Identity::Session.count", "Identity::PendingRegistration.count" ] do
        error = assert_raises(Errors::RegistrationUnavailable) { Registration::CompleteRegistration.call(token: token_for(record)) }
      end
      assert_nil error.cause
      assert_equal existing_attributes, existing.reload.slice(:id, :email_address, :password_digest, :email_confirmed_at)
      assert Identity::PendingRegistration.exists?(record.id)
    end

    test "a nested validation failure is not mistaken for target email conflict" do
      record = prepare
      token = token_for(record)
      other_record = Identity::PendingRegistration.new
      other_record.errors.add(:email_address, :taken)
      failure = ActiveRecord::RecordInvalid.new(other_record)
      callback = -> { raise failure }
      Identity::UserRegistered.set_callback(:validation, :before, callback)
      assert_no_difference [ "Identity::User.count", "Identity::Session.count", "Identity::PendingRegistration.count" ] do
        assert_same failure, assert_raises(ActiveRecord::RecordInvalid) { Registration::CompleteRegistration.call(token:) }
      end
      assert Identity::PendingRegistration.exists?(record.id)
    ensure
      Identity::UserRegistered.skip_callback(:validation, :before, callback, raise: false) if callback
    end

    test "failure at each mutation stage rolls back the entire guest completion" do
      guest = Identity::UserGuest.create!
      Identity::Session.create!(user: guest)
      record = prepare(guest_user_id: guest.id)
      token = token_for(record)
      user_before = guest.slice(:id, :created_at, :email_address, :password_digest)
      pending_before = record.slice(:id, :guest_user_id, :email_address, :password_digest, :created_at)
      sessions_before = Identity::Session.where(user_id: guest.id).order(:id).pluck(:id, :user_id, :created_at)
      [ /UPDATE "users"/, /DELETE FROM "sessions"/, /INSERT INTO "sessions"/, /DELETE FROM "pending_registrations"/ ].each do |pattern|
        listener = ->(event) { raise IOError, "simulated persistence failure" if event.payload[:sql].match?(pattern) }
        assert_raises(IOError) do
          ActiveSupport::Notifications.subscribed(listener, "sql.active_record") do
            Registration::CompleteRegistration.call(token:)
          end
        end
        assert_equal user_before, Identity::User.find(guest.id).slice(:id, :created_at, :email_address, :password_digest)
        assert_equal pending_before, Identity::PendingRegistration.find(record.id).slice(:id, :guest_user_id, :email_address, :password_digest, :created_at)
        assert_equal sessions_before, Identity::Session.where(user_id: guest.id).order(:id).pluck(:id, :user_id, :created_at)
      end
      assert Registration::CompleteRegistration.call(token:).active?
    end

    test "token and credential markers stay out of logs and expected errors" do
      record = prepare
      token = token_for(record)
      output = StringIO.new
      original_logger = ActiveRecord::Base.logger
      ActiveRecord::Base.logger = ActiveSupport::Logger.new(output)
      Registration::CompleteRegistration.call(token:)
      error = assert_raises(Errors::RegistrationUnavailable) { Registration::CompleteRegistration.call(token:) }
      [ output.string, error.full_message, record.inspect ].each do |text|
        [ token, record.email_address, record.password_digest, "a long password phrase" ].each { |marker| refute_includes text, marker }
      end
    ensure
      ActiveRecord::Base.logger = original_logger
    end
  end
end

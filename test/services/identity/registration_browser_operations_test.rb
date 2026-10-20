require "test_helper"

module Identity
  class RegistrationBrowserOperationsTest < ActiveSupport::TestCase
    def prepare(**attributes)
      PrepareRegistration.call(email_address: "reader@example.test", password: "a long password phrase",
        password_confirmation: "a long password phrase", **attributes)
    end

    test "attachment is idempotent preserves token and rejects either conflicting link" do
      record = prepare
      token = RegistrationConfirmation.token_for(pending_registration_id: record.id)
      guest = UserGuest.create!
      before = record.slice(:id, :email_address, :password_digest, :created_at)
      2.times { AttachRegistration.call(pending_registration_id: record.id, guest_user_id: guest.id) }
      assert_equal before, record.reload.slice(:id, :email_address, :password_digest, :created_at)
      assert_equal record, PendingRegistration.find_by_token_for(:email_confirmation, token)
      other_guest = UserGuest.create!
      assert_raises(RegistrationConflict) { AttachRegistration.call(pending_registration_id: record.id, guest_user_id: other_guest.id) }
      direct = prepare
      assert_raises(RegistrationConflict) { AttachRegistration.call(pending_registration_id: direct.id, guest_user_id: guest.id) }
      assert_nil direct.reload.guest_user_id
      assert_equal guest.id, record.reload.guest_user_id
    end

    test "attachment rejects expired missing deleted and registered owners without mutation" do
      freeze_time
      record = prepare
      guest = UserGuest.create!
      guest.update_columns(type: "UserDeleted")
      registered = UserRegistered.create!(email_address: "registered@example.test", password: "a long password phrase",
        password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
      [ -1, guest.id, registered.id ].each do |id|
        assert_raises(RegistrationUnavailable) { AttachRegistration.call(pending_registration_id: record.id, guest_user_id: id) }
      end
      fresh_guest = UserGuest.create!
      travel 24.hours
      assert_raises(RegistrationUnavailable) { AttachRegistration.call(pending_registration_id: record.id, guest_user_id: fresh_guest.id) }
      assert_nil record.reload.guest_user_id
    end

    test "browser completion only attaches a direct request the browser owns" do
      record = prepare
      guest = UserGuest.create!
      token = RegistrationConfirmation.token_for(pending_registration_id: record.id)
      assert_raises(RegistrationConflict) { CompleteBrowserRegistration.call(token:, current_user_id: guest.id) }
      assert_nil record.reload.guest_user_id
      session = CompleteBrowserRegistration.call(token:, current_user_id: guest.id, pending_registration_id: record.id)
      assert_equal guest.id, session.user_id
      assert (session.user).can_reset_password?
    end

    test "failed browser confirmation rolls back attachment" do
      record = prepare
      UserRegistered.create!(email_address: "reader@example.test", password: "existing password phrase",
        password_confirmation: "existing password phrase", email_confirmed_at: Time.current)
      guest = UserGuest.create!
      token = RegistrationConfirmation.token_for(pending_registration_id: record.id)
      assert_raises(RegistrationUnavailable) do
        CompleteBrowserRegistration.call(token:, current_user_id: guest.id, pending_registration_id: record.id)
      end
      assert_nil record.reload.guest_user_id
      assert_not (User.find(guest.id)).can_reset_password?
    end

    test "invalid replacement retains prior direct record while valid replacement deletes it" do
      record = prepare
      assert_raises(ActiveRecord::RecordInvalid) do
        SubmitRegistration.call(previous_id: record.id, email_address: "invalid", password: "tiny", password_confirmation: "tiny")
      end
      assert PendingRegistration.exists?(record.id)
      replacement = SubmitRegistration.call(previous_id: record.id, email_address: "new@example.test",
        password: "a long password phrase", password_confirmation: "a long password phrase")
      assert_not PendingRegistration.exists?(record.id)
      assert_equal "new@example.test", replacement.email_address
    end

    test "origin validation rejects missing nonroot credential and nonHTTPS origins before reserving" do
      original = ENV["APP_ORIGIN"]
      record = prepare
      [ nil, "", "https://user:pass@example.test", "https://example.test/path", "https://example.test?x=1",
        "https://example.test#fragment", "http://remote.example", "http://localhost:3000", "broken origin" ].each do |origin|
        ENV["APP_ORIGIN"] = origin
        assert_raises(ArgumentError) { DeliverRegistrationConfirmation.call(pending_registration_id: record.id) }
        assert_equal 0, record.reload.confirmation_delivery_attempts
      end
    ensure
      ENV["APP_ORIGIN"] = original
    end

    test "development SMTP permits localhost links while production and remote HTTP reject" do
      original_origin = ENV["APP_ORIGIN"]
      original_environment = Rails.env
      original_method = AccountMailer.delivery_method
      AccountMailer.delivery_method = :smtp
      Rails.env = "development"
      ENV["APP_ORIGIN"] = "http://localhost:3000"
      assert_equal "http://localhost:3000", DeliverRegistrationConfirmation.send(:validated_origin)
      assert AccountMailer.confirmation(recipient: "reader@example.test", confirmation_url: "http://localhost:3000/registration_confirmation?token=example").message.multipart?
      ENV["APP_ORIGIN"] = "http://remote.example"
      assert_raises(ArgumentError) { DeliverRegistrationConfirmation.send(:validated_origin) }
      Rails.env = "production"
      ENV["APP_ORIGIN"] = "http://localhost:3000"
      assert_raises(ArgumentError) { DeliverRegistrationConfirmation.send(:validated_origin) }
      assert_raises(ArgumentError) { AccountMailer.confirmation(recipient: "reader@example.test", confirmation_url: "http://localhost:3000/registration_confirmation?token=example").message }
    ensure
      ENV["APP_ORIGIN"] = original_origin
      Rails.env = original_environment
      AccountMailer.delivery_method = original_method
    end

    test "resend stops when another request already registered the email" do
      record = prepare
      UserRegistered.create!(email_address: record.email_address, password: "existing password phrase",
        password_confirmation: "existing password phrase", email_confirmed_at: Time.current)
      original_origin = ENV["APP_ORIGIN"]
      ENV["APP_ORIGIN"] = "https://glutton.example.test"
      assert_no_difference "ActionMailer::Base.deliveries.count" do
        assert_raises(RegistrationUnavailable) { DeliverRegistrationConfirmation.call(pending_registration_id: record.id) }
      end
      assert_equal 0, record.reload.confirmation_delivery_attempts
    ensure
      ENV["APP_ORIGIN"] = original_origin
    end

    test "database bounds delivery counters even without model validation" do
      record = prepare
      [ -1, 6, nil ].each do |count|
        assert_raises(ActiveRecord::StatementInvalid) do
          PendingRegistration.transaction(requires_new: true) { record.update_columns(confirmation_delivery_attempts: count) }
        end
      end
    end
  end
end

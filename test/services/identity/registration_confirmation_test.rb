require "test_helper"

module Identity
  class RegistrationConfirmationTest < ActiveSupport::TestCase
    def prepare(**attributes)
      PrepareRegistration.call(email_address: "private-reader@example.test", password: "a long password phrase",
        password_confirmation: "a long password phrase", **attributes)
    end

    def token_for(record)
      RegistrationConfirmation.token_for(pending_registration_id: record.id)
    end

    test "issuance changes no identity or delivery and exposes no credentials" do
      record = prepare
      assert_no_difference [ "User.count", "Session.count", "ActionMailer::Base.deliveries.count" ] do
        token = token_for(record)
        assert_equal record, PendingRegistration.find_by_token_for(:email_confirmation, token)
        definition = PendingRegistration.token_definitions.fetch(:email_confirmation)
        payload = definition.message_verifier.verified(token, purpose: definition.full_purpose).to_json
        [ record.email_address, record.password_digest, "a long password phrase" ].each { |marker| refute_includes payload, marker }
      end
    end

    test "token expires exactly one hour after issuance" do
      freeze_time
      record = prepare
      issued_at = Time.current
      token = token_for(record)
      travel_to issued_at + 1.hour - 1.second
      assert_equal record, PendingRegistration.find_by_token_for(:email_confirmation, token)
      travel_to issued_at + 1.hour
      assert_nil PendingRegistration.find_by_token_for(:email_confirmation, token)
      assert_raises(RegistrationUnavailable) { CompleteRegistration.call(token:) }
    end

    test "pending and guest deadlines cap issuance and completion" do
      freeze_time
      direct = prepare
      travel_to direct.expires_at - 30.minutes
      token = token_for(direct)
      travel_to direct.expires_at
      assert_not direct.active?
      assert_raises(RegistrationUnavailable) { token_for(direct) }
      assert_raises(RegistrationUnavailable) { CompleteRegistration.call(token:) }
      guest = UserGuest.create!
      travel_to guest.created_at + UserGuest::EXPIRY_DURATION - 30.minutes
      linked = prepare(guest_user_id: guest.id)
      token = token_for(linked)
      travel_to guest.created_at + UserGuest::EXPIRY_DURATION
      assert_raises(RegistrationUnavailable) { CompleteRegistration.call(token:) }
      assert_raises(RegistrationUnavailable) { token_for(linked) }
    end

    test "credential mutation replacement deletion and wrong purpose invalidate tokens" do
      record = prepare
      token = token_for(record)
      record.update!(email_address: "changed@example.test")
      assert_nil PendingRegistration.find_by_token_for(:email_confirmation, token)
      token = token_for(record)
      record.update!(password: "a replacement password", password_confirmation: "a replacement password")
      assert_nil PendingRegistration.find_by_token_for(:email_confirmation, token)
      assert_raises(RegistrationUnavailable) { CompleteRegistration.call(token: record.signed_id(purpose: :other)) }
      token = token_for(record)
      record.destroy!
      assert_raises(RegistrationUnavailable) { CompleteRegistration.call(token:) }
      assert_raises(RegistrationUnavailable) { token_for(record) }
      guest = UserGuest.create!
      linked = prepare(guest_user_id: guest.id)
      token = token_for(linked)
      prepare(guest_user_id: guest.id)
      assert_raises(RegistrationUnavailable) { CompleteRegistration.call(token:) }
    end

    test "unchanged request can issue multiple tokens and completion invalidates all" do
      record = prepare
      first = token_for(record)
      second = travel(1.second) { token_for(record) }
      assert_equal record, PendingRegistration.find_by_token_for(:email_confirmation, first)
      assert_equal record, PendingRegistration.find_by_token_for(:email_confirmation, second)
      CompleteRegistration.call(token: second)
      assert_raises(RegistrationUnavailable) { CompleteRegistration.call(token: first) }
    end
  end
end

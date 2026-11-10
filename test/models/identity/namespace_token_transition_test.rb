require "test_helper"

class Identity::NamespaceTokenTransitionTest < ActiveSupport::TestCase
  test "pre-namespace confirmation links are invalid while newly issued links resolve" do
    registration = Identity::Registration::PrepareRegistration.call(email_address: "namespace@example.test",
      password: "a long password phrase", password_confirmation: "a long password phrase")
    old_token = legacy_token(record: registration, purpose: :email_confirmation, class_name: "PendingRegistration")
    assert_raises(Identity::Errors::RegistrationUnavailable) do
      Identity::PendingRegistration.resolve_confirmation!(token: old_token)
    end
    new_token = Identity::Registration::RegistrationConfirmation.token_for(pending_registration_id: registration.id)
    assert_equal registration, Identity::PendingRegistration.resolve_confirmation!(token: new_token)
  end

  test "pre-namespace reset links are invalid while newly issued links resolve" do
    user = Identity::UserRegistered.create!(email_address: "namespace@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    old_token = legacy_token(record: user, purpose: :password_reset, class_name: "UserRegistered")
    assert_nil Identity::UserRegistered.find_by_password_reset_token(old_token)
    assert_equal user, Identity::UserRegistered.find_by_password_reset_token(user.password_reset_token)
  end

  private

  def legacy_token(record:, purpose:, class_name:)
    # Migration contract: reproduce the previous Rails token purpose without
    # defining legacy production classes or changing the record's credentials.
    definition = record.class.token_definitions.fetch(purpose)
    record.class.generated_token_verifier.generate(definition.payload_for(record), expires_in: definition.expires_in,
      purpose: [ class_name, purpose, definition.expires_in ].join("\n"))
  end
end

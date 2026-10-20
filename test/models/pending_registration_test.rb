require "test_helper"
require "stringio"

class PendingRegistrationTest < ActiveSupport::TestCase
  def registration(**attributes)
    PendingRegistration.new(email_address: "reader@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", **attributes)
  end

  test "credentials normalize hash and remain separate from user identity" do
    assert_no_difference [ "User.count", "Session.count" ] do
      record = registration(email_address: " Reader@Example.TEST \t")
      record.save!
      record.reload
      assert_nil record.guest_user_id
      assert_equal "reader@example.test", record.email_address
      assert_equal record, record.authenticate("a long password phrase")
      assert_not record.authenticate("incorrect password")
      refute_equal "a long password phrase", record.password_digest
      refute record.has_attribute?(:password)
      refute record.has_attribute?(:password_confirmation)
      assert_nil Identity::Authenticate.call(email_address: record.email_address, password: "a long password phrase")
    end
  end

  test "password policy includes fresh password confirmation and byte boundaries" do
    [ nil, "", "a" * 14, "a" * 73, "é" * 37 ].each do |password|
      record = registration(password: password, password_confirmation: password)
      assert_not record.valid?, password.inspect
      assert record.errors[:password].any?
    end
    [ "a" * 15, "a" * 72, "é" * 36 ].each do |password|
      assert registration(password: password, password_confirmation: password).valid?
    end
    [ nil, "", "different password" ].each do |confirmation|
      assert_not registration(password_confirmation: confirmation).valid?
    end
    assert_not registration(password: nil, password_confirmation: nil, password_digest: "digest").valid?
    [ nil, "", "invalid", "a b@example.test" ].each do |email|
      record = registration(email_address: email)
      assert_not record.valid?
      assert record.errors[:email_address].any?
      assert record.errors.full_messages.any? { |message| message.start_with?("Email ") }
    end
  end

  test "database independently enforces canonical credentials optional foreign key and unique guest" do
    guest = UserGuest.create!
    registration(guest_user: guest).save!
    invalid_rows = [
      { email_address: nil }, { email_address: "" }, { email_address: "Reader@example.test" },
      { email_address: " reader@example.test" }, { password_digest: nil }, { password_digest: " \t" },
      { guest_user_id: -1 }, { guest_user_id: guest.id }
    ]
    invalid_rows.each do |attributes|
      assert_raises(ActiveRecord::StatementInvalid) do
        PendingRegistration.transaction(requires_new: true) do
          row = registration.tap(&:save!)
          connection = PendingRegistration.connection
          updates = attributes.map { |key, value| "#{connection.quote_column_name(key)} = #{connection.quote(value)}" }.join(", ")
          connection.execute("UPDATE pending_registrations SET #{updates} WHERE id = #{row.id}")
        end
      end
    end
    assert_difference "PendingRegistration.count", 2 do
      2.times { registration.save! }
    end
  end

  test "guest deletion removes only linked pending credentials" do
    guest = UserGuest.create!
    other_guest = UserGuest.create!
    linked = registration(guest_user: guest).tap(&:save!)
    other = registration(guest_user: other_guest).tap(&:save!)
    direct = registration.tap(&:save!)
    guest.delete
    assert_not PendingRegistration.exists?(linked.id)
    assert PendingRegistration.exists?(other.id)
    assert PendingRegistration.exists?(direct.id)
    assert User.exists?(other_guest.id)
  end

  test "routine logs parameter filtering and inspection omit credential markers" do
    output = StringIO.new
    original_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = ActiveSupport::Logger.new(output)
    record = registration(email_address: "private-reader@example.test", password: "private-password-marker",
      password_confirmation: "private-password-marker")
    record.save!
    record.reload
    inspected = record.inspect
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(
      email_address: record.email_address, password: "private-password-marker", password_confirmation: "private-password-marker", password_digest: record.password_digest)
    [ output.string, inspected, filtered.inspect ].each do |text|
      [ record.email_address, "private-password-marker", record.password_digest ].each { |marker| refute_includes text, marker }
    end
  ensure
    ActiveRecord::Base.logger = original_logger
  end
end

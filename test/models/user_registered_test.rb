require "test_helper"

class UserRegisteredTest < ActiveSupport::TestCase
  def account(**attributes)
    UserRegistered.new(email_address: "viewer@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current, **attributes)
  end

  test "confirmed credentials persist and authenticate without a guest deadline" do
    user = account
    user.save!
    loaded = User.find(user.id)
    assert_instance_of UserRegistered, loaded
    assert_equal loaded, loaded.authenticate("a long password phrase")
    assert_not loaded.authenticate("incorrect password")
    assert_not_equal "a long password phrase", loaded.password_digest
    assert_not loaded.has_attribute?(:password)
    assert_not loaded.has_attribute?(:password_confirmation)
    assert loaded.respond_to?(:password_reset_token)
    travel 48.hours do
      assert loaded.active?
    end
    assert loaded.save!
  end

  test "email and confirmation timestamp are required" do
    [ nil, "", "bad-address", "a b@example.test" ].each do |email|
      assert_not account(email_address: email).valid?, email.inspect
    end
    assert_not account(email_confirmed_at: nil).valid?
  end

  test "password and confirmation enforce character and byte boundaries" do
    [ nil, "", "a" * 14, "a" * 73, "é" * 37 ].each do |password|
      assert_not account(password: password, password_confirmation: password).valid?, password.inspect
    end
    [ "a" * 15, "a" * 72, "é" * 36, "a phrase with spaces" ].each do |password|
      assert account(password: password, password_confirmation: password).valid?, password.inspect
    end
    assert_not account(password: nil, password_confirmation: nil, password_digest: "digest").valid?
    assert_not account(password_confirmation: nil).valid?
    assert_not account(password_confirmation: "different confirmation").valid?
    user = account
    user.save!
    user.reload
    assert user.valid?
    user.password = "short"
    user.password_confirmation = "short"
    assert_not user.valid?
  end

  test "email normalization lookup and uniqueness do not create accounts" do
    user = account(email_address: " Viewer@Example.test \t")
    user.save!
    assert_equal "viewer@example.test", user.reload.email_address
    assert_no_difference "User.count" do
      assert_equal user, UserRegistered.find_by_email(" VIEWER@example.TEST ")
      [ nil, "", "bad-address", "unknown@example.test", 42 ].each do |input|
        assert_nil UserRegistered.find_by_email(input)
      end
    end
    assert_not account(email_address: "VIEWER@example.test").valid?
    assert account(email_address: "viewer+extra@example.test").save!
    assert_not_equal user, UserRegistered.find_by_email("viewer+extra@example.test")
    assert_nil UserRegistered.find_by_email(nil)
    UserGuest.create!
    UserDeleted.create!
    assert UserRegistered.all.all? { |record| record.instance_of?(UserRegistered) }
  end

  test "guests and deleted users reject any credential field" do
    [ UserGuest, UserDeleted ].each do |model|
      { email_address: "viewer@example.test", password_digest: "digest", email_confirmed_at: Time.current }.each do |field, value|
        assert_not model.new(field => value).valid?
        assert model.new.valid?
      end
    end
  end

  test "database enforces registered credentials independently of validations" do
    row = { type: "UserRegistered", email_address: "database@example.test", password_digest: "digest",
      email_confirmed_at: Time.current, created_at: Time.current, updated_at: Time.current }
    [ { email_address: nil }, { email_address: "" }, { email_address: "UPPER@example.test" },
      { email_address: " viewer@example.test" }, { password_digest: nil }, { password_digest: "" },
      { password_digest: " \t" }, { email_confirmed_at: nil } ].each do |invalid|
      assert_constraint_rejects(row.merge(invalid), "registered_users_require_credentials")
    end
    User.insert_all!([ row ])
    assert_raises ActiveRecord::RecordNotUnique do
      User.transaction(requires_new: true) { User.insert_all!([ row ]) }
    end
  end

  test "database keeps guest and deleted credentials null" do
    [ "UserGuest", "UserDeleted" ].each do |type|
      row = { type: type, created_at: Time.current, updated_at: Time.current }
      { email_address: "db@example.test", password_digest: "digest", email_confirmed_at: Time.current }.each do |field, value|
        assert_constraint_rejects(row.merge(field => value), "other_users_have_no_credentials")
      end
    end
  end

  test "routine parameter filtering redacts credentials including nested values" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter(email_address: "viewer@example.test", password: "secret", user: { password_confirmation: "secret" })
    assert_equal "[FILTERED]", filtered[:email_address]
    assert_equal "[FILTERED]", filtered[:password]
    assert_equal "[FILTERED]", filtered[:user][:password_confirmation]
  end

  private

  def assert_constraint_rejects(attributes, constraint)
    error = assert_raises ActiveRecord::StatementInvalid do
      User.transaction(requires_new: true) { User.insert_all!([ attributes ]) }
    end
    assert_includes error.message, constraint
  end
end

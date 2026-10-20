require "test_helper"

module Identity
  class ResolvePasswordResetTest < ActiveSupport::TestCase
    setup do
      @user = UserRegistered.create!(email_address: "resolve-reset@example.test", password: "original password phrase",
        password_confirmation: "original password phrase", email_confirmed_at: Time.current)
      @token = @user.password_reset_token
    end

    test "valid token resolves its target for anonymous same-account and guest browsers without writes" do
      guest = UserGuest.create!
      assert_no_difference [ "User.count", "Session.count" ] do
        [ nil, @user.id, guest.id ].each do |current_user_id|
          assert_equal @user, ResolvePasswordReset.call(token: @token, current_user_id:)
        end
      end
      assert @user.reload.authenticate("original password phrase")
    end

    test "an unrelated identity with its own password reset action conflicts" do
      other = UserRegistered.create!(email_address: "other-reset@example.test", password: "original password phrase",
        password_confirmation: "original password phrase", email_confirmed_at: Time.current)
      assert_no_difference [ "User.count", "Session.count" ] do
        assert_raises(PasswordResetConflict) { ResolvePasswordReset.call(token: @token, current_user_id: other.id) }
      end
      assert @user.reload.authenticate("original password phrase")
    end

    test "invalid and expired tokens fail before browser-context resolution" do
      [ nil, "", [], "tampered" ].each do |token|
        assert_raises(PasswordResetUnavailable) { ResolvePasswordReset.call(token:) }
      end
      travel 16.minutes do
        assert_raises(PasswordResetUnavailable) { ResolvePasswordReset.call(token: @token) }
      end
    end
  end
end

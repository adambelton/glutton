require "test_helper"

module Identity
  class ResetPasswordTest < ActiveSupport::TestCase
    setup do
      @user = UserRegistered.create!(email_address: "reset@example.test", password: "original password phrase",
        password_confirmation: "original password phrase", email_confirmed_at: Time.current)
      @token = @user.password_reset_token
      2.times { Session.create!(user: @user) }
    end

    def reset(password: "replacement password phrase", password_confirmation: password, token: @token)
      ResetPassword.call(token:, password:, password_confirmation:)
    end

    test "native tokens expire at fifteen minutes and expose no credentials" do
      freeze_time do
        token = @user.password_reset_token
        definition = UserRegistered.token_definitions.fetch(:password_reset)
        payload = definition.message_verifier.verified(token, purpose: definition.full_purpose).to_json
        [ @user.email_address, @user.password_digest, "original password phrase" ].each { |value| refute_includes payload, value }
        travel 899.seconds
        assert_equal @user, UserRegistered.find_by_password_reset_token(token)
        travel 1.second
        assert_raises(PasswordResetUnavailable) { reset(token:) }
      end
      [ nil, "", "tampered", @user.signed_id(purpose: :other) ].each do |token|
        assert_raises(PasswordResetUnavailable) { reset(token:) }
      end
      [ UserGuest.create!, UserDeleted.create! ].each do |user|
        assert_not user.can_reset_password?
        assert_no_difference "Session.count" do
          assert_raises(PasswordResetUnavailable) do
            user.reset_password!(password: "replacement password phrase", password_confirmation: "replacement password phrase")
          end
        end
      end
    end

    test "validation preserves digest sessions and token at all policy boundaries" do
      digest = @user.password_digest
      [ [ nil, nil ], [ "", "" ], [ "x" * 14, "x" * 14 ], [ "x" * 15, nil ],
        [ "x" * 15, "different password" ], [ "x" * 73, "x" * 73 ], [ "é" * 37, "é" * 37 ] ].each do |password, password_confirmation|
        assert_raises(ActiveRecord::RecordInvalid) { reset(password:, password_confirmation:) }
        assert_equal digest, @user.reload.password_digest
        assert_equal 2, Session.where(user: @user).count
        assert_equal @user, UserRegistered.find_by_password_reset_token(@token)
      end
      [ "x" * 15, "x" * 72, "é" * 36 ].each do |password|
        @token = @user.reload.password_reset_token
        reset(password:)
        assert @user.reload.authenticate(password)
      end
    end

    test "success revokes only target sessions invalidates all links and never authenticates" do
      guest_session = Session.create!(user: UserGuest.create!)
      second_token = travel(1.second) { @user.password_reset_token }
      assert_no_difference "User.count" do
        assert_difference "Session.count", -2 do
          assert_equal @user, reset
        end
      end
      assert guest_session.active?
      assert_not @user.reload.authenticate("original password phrase")
      assert @user.authenticate("replacement password phrase")
      [ @token, second_token ].each { |token| assert_raises(PasswordResetUnavailable) { reset(token:) } }
    end

    test "session deletion failure rolls back the digest and sessions" do
      digest = @user.password_digest
      callback = ->(*args) do
        event = ActiveSupport::Notifications::Event.new(*args)
        raise IOError, "simulated deletion failure" if event.payload[:sql].match?(/DELETE FROM "sessions"/)
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        assert_raises(IOError) { reset }
      end
      assert_equal digest, @user.reload.password_digest
      assert_equal 2, Session.where(user: @user).count
      assert_equal @user, UserRegistered.find_by_password_reset_token(@token)
    end

    test "deleted account cannot redeem an earlier token" do
      @user.update_columns(type: "UserDeleted", email_address: nil, password_digest: nil, email_confirmed_at: nil)
      assert_raises(PasswordResetUnavailable) { reset }
    end
  end
end

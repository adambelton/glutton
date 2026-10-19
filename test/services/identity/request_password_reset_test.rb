require "test_helper"

module Identity
  class RequestPasswordResetTest < ActiveSupport::TestCase
    setup do
      @origin = ENV["APP_ORIGIN"]
      ENV["APP_ORIGIN"] = "https://glutton.example.test"
      @user = RegisteredUser.create!(email_address: "mail-reset@example.test", password: "original password phrase",
        password_confirmation: "original password phrase", email_confirmed_at: Time.current)
      ActionMailer::Base.deliveries.clear
    end

    teardown { ENV["APP_ORIGIN"] = @origin }

    test "normalized lookup sends exact recipient and trusted reset link without identity changes" do
      digest = @user.password_digest
      assert_no_difference [ "User.count", "Session.count", "PendingRegistration.count" ] do
        assert_nil RequestPasswordReset.call(email_address: " MAIL-RESET@example.test ")
      end
      mail = ActionMailer::Base.deliveries.last
      assert_equal [ @user.email_address ], mail.to
      url = mail.text_part.body.decoded.lines.map(&:strip).find { |line| line.start_with?("https://") }
      uri = URI.parse(url)
      assert_equal "glutton.example.test", uri.host
      assert_equal "/password_reset/edit", uri.path
      token = URI.decode_www_form(uri.query).to_h.fetch("token")
      assert_equal @user, RegisteredUser.find_by_password_reset_token(token)
      assert_equal digest, @user.reload.password_digest
    end

    test "unknown pending malformed and deleted identities send nothing" do
      PrepareRegistration.call(email_address: "pending@example.test", password: "original password phrase",
        password_confirmation: "original password phrase")
      @user.update_columns(type: "DeletedUser", email_address: nil, password_digest: nil, email_confirmed_at: nil)
      assert_no_difference [ "User.count", "Session.count", "ActionMailer::Base.deliveries.count" ] do
        [ "unknown@example.test", "pending@example.test", "mail-reset@example.test", nil, [], "invalid" ].each do |email|
          assert_nil RequestPasswordReset.call(email_address: email)
        end
      end
    end

    test "known transport failures are sanitized while unexpected errors propagate" do
      original = AccountMailer.method(:password_reset)
      AccountMailer.define_singleton_method(:password_reset) { |**| raise Net::SMTPFatalError, "private provider detail" }
      error = assert_raises(RequestPasswordReset::Failed) { RequestPasswordReset.call(email_address: @user.email_address) }
      assert_nil error.cause
      refute_includes error.message, "private provider detail"
      AccountMailer.define_singleton_method(:password_reset) { |**| raise ArgumentError, "unexpected" }
      assert_raises(ArgumentError) { RequestPasswordReset.call(email_address: @user.email_address) }
    ensure
      AccountMailer.define_singleton_method(:password_reset, original) if original
    end
  end
end

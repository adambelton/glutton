require "test_helper"
require "stringio"

module Identity
  class AccountMailerTest < ActionMailer::TestCase
    test "both messages render multipart content without account or session changes" do
      assert_no_difference [ "User.count", "Session.count" ] do
        { confirmation: :confirmation_url, password_reset: :reset_url }.each do |action, argument|
          url = "https://example.test/action?token=private-marker&other=escaped"
          message = AccountMailer.public_send(action, recipient: "reader@example.test", argument => url).message
          assert_equal [ "reader@example.test" ], message.to
          assert_equal [ "noreply@example.test" ], message.from
          assert_nil message.cc
          assert_nil message.bcc
          assert_match(action == :confirmation ? /Confirm/ : /Reset/, message.subject)
          assert_includes message.text_part.body.decoded, url
          assert_includes message.html_part.body.decoded, "&amp;other=escaped"
          assert_includes message.text_part.body.decoded, "ignore this email"
          assert_includes message.html_part.body.decoded, "ignore this email"
        end
      end
    end

    test "rejects invalid recipients and links before delivery" do
      [ nil, "", "invalid", "a,b@example.test", "Reader <a@example.test>", "a@example.test,b@example.test", "a@example.test\r\nBcc: b@example.test" ].each do |recipient|
        assert_raises(ArgumentError) { AccountMailer.confirmation(recipient: recipient, confirmation_url: "https://example.test/confirm").deliver_now }
      end
      [ nil, "", "/relative", "javascript:alert(1)", "https:///missing", "https://user:pass@example.test", "http://example.test", "https://example.test/\r\nheader" ].each do |url|
        assert_raises(ArgumentError) { AccountMailer.password_reset(recipient: "reader@example.test", reset_url: url).deliver_now }
      end
      assert_no_emails
    end

    test "default delivery is local and routine logs omit message data" do
      output = StringIO.new
      original_logger = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(output)
      assert_nil AccountMailer.logger
      assert_equal :test, AccountMailer.delivery_method
      assert_emails 1 do
        AccountMailer.confirmation(recipient: "private-recipient@example.test", confirmation_url: "https://example.test/?token=private-token").deliver_now
      end
      refute_includes output.string, "private-recipient"
      refute_includes output.string, "private-token"
    ensure
      Rails.logger = original_logger
    end

    test "SMTP transport settings reach the boundary and failures propagate once" do
      output = StringIO.new
      original_logger = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(output)
      settings = Glutton::MailDelivery.settings(environment: "development", env: {
        "MAIL_DELIVERY" => "resend", "MAIL_FROM" => "sender@example.test", "RESEND_API_KEY" => "private-key-marker"
      })
      message = AccountMailer.confirmation(recipient: "reader@example.test", confirmation_url: "https://example.test/confirm").message
      message.delivery_method(:smtp, settings.fetch(:smtp_settings))
      transport = message.delivery_method
      calls = 0
      transport.define_singleton_method(:deliver!) do |_mail|
        calls += 1
        raise IOError, "simulated SMTP failure"
      end
      assert_equal "private-key-marker", transport.settings[:password]
      assert_no_difference [ "User.count", "Session.count" ] do
        assert_raises(IOError) { message.deliver }
      end
      assert_equal 1, calls
      transport.define_singleton_method(:deliver!) { |_mail| calls += 1 }
      message.deliver
      assert_equal 2, calls
      %w[private-key-marker reader@example.test example.test/confirm].each { |marker| refute_includes output.string, marker }
    ensure
      Rails.logger = original_logger
    end
  end
end

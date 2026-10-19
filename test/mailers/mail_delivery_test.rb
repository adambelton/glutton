require "test_helper"
require_relative "../../config/mail_delivery"

class MailDeliveryTest < ActiveSupport::TestCase
  test "defaults are local and previews are development only" do
    %w[development test production].each do |environment|
      settings = Glutton::MailDelivery.settings(environment: environment, env: { "RESEND_API_KEY" => "ignored" })
      assert_equal :test, settings[:delivery_method]
      assert_equal(environment == "development", settings[:show_previews])
      assert_nil settings[:logger]
    end
  end

  test "test environment ignores live and malformed configuration" do
    %w[resend invalid].each do |mode|
      settings = Glutton::MailDelivery.settings(environment: "test", env: { "MAIL_DELIVERY" => mode })
      assert_equal :test, settings[:delivery_method]
      refute settings.key?(:smtp_settings)
    end
  end

  test "explicit Resend configuration requires credentials and a single sender" do
    base = { "MAIL_DELIVERY" => "resend", "MAIL_FROM" => "sender@example.test", "RESEND_API_KEY" => "private-key-marker" }
    %w[development production].each do |environment|
      %w[MAIL_FROM RESEND_API_KEY].each do |key|
        [ nil, "", " " ].each do |value|
          assert_raises(ArgumentError) { Glutton::MailDelivery.settings(environment: environment, env: base.merge(key => value)) }
        end
      end
      [ "a@example.test,b@example.test", "a@example.test\nBcc: b@example.test" ].each do |sender|
        assert_raises(ArgumentError) { Glutton::MailDelivery.settings(environment: environment, env: base.merge("MAIL_FROM" => sender)) }
      end
      assert_raises(ArgumentError) { Glutton::MailDelivery.settings(environment: environment, env: { "MAIL_DELIVERY" => "typo" }) }
      settings = Glutton::MailDelivery.settings(environment: environment, env: base)
      assert_equal :smtp, settings[:delivery_method]
      assert settings[:raise_delivery_errors]
      assert_equal({ from: "sender@example.test" }, settings[:default_options])
      smtp = settings[:smtp_settings]
      assert_equal "smtp.resend.com", smtp[:address]
      assert_equal 587, smtp[:port]
      assert_equal "resend", smtp[:user_name]
      assert_equal :plain, smtp[:authentication]
      assert_equal true, smtp[:enable_starttls]
      assert_equal "peer", smtp[:openssl_verify_mode]
      refute smtp.key?(:enable_starttls_auto)
    end
  end
end

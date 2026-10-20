require "test_helper"
require "open3"

class IdentityCleanupTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def command(*arguments)
    # Select this worker's test database explicitly; never inherit a development URL.
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    uri = URI::Generic.build(scheme: "postgresql", host: config.fetch(:host), port: config[:port],
      path: "/#{config.fetch(:database)}")
    if config[:username].present?
      uri.user = ERB::Util.url_encode(config[:username])
      uri.password = ERB::Util.url_encode(config[:password]) if config[:password].present?
    end
    Open3.capture3({ "RAILS_ENV" => "test", "DATABASE_URL" => uri.to_s }, RbConfig.ruby, "bin/rails", *arguments)
  end

  test "real command deletes test records reports aggregate counts and safely repeats" do
    guest = UserGuest.create!(created_at: 25.hours.ago)
    stdout, stderr, status = command("identity:cleanup_expired")
    assert status.success?, stderr
    assert_equal "guests_deleted=1 pending_registrations_deleted=0\n", stdout
    assert_not User.exists?(guest.id)
    stdout, stderr, status = command("identity:cleanup_expired")
    assert status.success?, stderr
    assert_equal "guests_deleted=0 pending_registrations_deleted=0\n", stdout
  ensure
    User.where(id: guest&.id).delete_all
  end

  test "command exits nonzero and excludes private exception details" do
    [ "ActiveRecord::StatementInvalid", "ArgumentError" ].each do |error_class|
      script = <<~CODE
        Rails.application.load_tasks
        Identity::CleanupExpiredAccounts.define_singleton_method(:call) { raise #{error_class}, "private-email@example.test private-password private-token" }
        Rake::Task["identity:cleanup_expired"].invoke
      CODE
      stdout, stderr, status = command("runner", script)
      assert_equal 1, status.exitstatus
      assert_empty stdout
      assert_includes stderr, "Identity cleanup failed (#{error_class})"
      [ "private-email@example.test", "private-password", "private-token" ].each { |marker| refute_includes stderr, marker }
    end
  end
end

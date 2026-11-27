require "test_helper"

class AccountDeletionLogTest < ActiveSupport::TestCase
  setup do
    @account = Identity::UserRegistered.create!(email_address: "delete-log@example.test",
      password: "a long test password", password_confirmation: "a long test password", email_confirmed_at: Time.current)
    Community::Membership::SetUpProfile.call(user_id: @account.id, displayed_version: Community::CodeOfConduct.current.version, accepted: true)
    @session = Identity::Session.create!(user: @account)
    @client = Aws::S3::Client.new(region: "auto", stub_responses: true)
    @log = Identity::AccountAdministration::DeletionLog.new(client: @client, bucket: "fixture", namespace: "recovery")
    @settings = Identity::AccountAdministration::ManageRegisteredAccount.new(user_id: @account.id)
  end

  test "writes only the deletion replay ID and timestamp before deleting account and session" do
    Community::Membership::ManageProfile.new(community_user: @account.community_user).change_community_username(community_username: "Former_Member")
    @client.stub_responses(:put_object, ->(context) do
      assert Identity::UserRegistered.exists?(@account.id)
      assert Identity::Session.exists?(@session.id)
      assert_equal "*", context.params.fetch(:if_none_match)
      record = JSON.parse(context.params.fetch(:body))
      assert_equal %w[account_id recorded_at], record.keys.sort
      assert_equal @account.deletion_replay_id, record.fetch("account_id")
      assert_in_delta Time.current.to_f, Time.iso8601(record.fetch("recorded_at")).to_f, 5
      {}
    end)

    @settings.close_account(deletion_log: @log)

    assert_not Identity::UserRegistered.exists?(@account.id)
    assert_not Identity::Session.exists?(@session.id)
    assert_username_released
  end

  test "keeps the account and session when R2 refuses the record" do
    @client.stub_responses(:put_object, "AccessDenied")

    assert_raises(Identity::Errors::DeletionLogUnavailable) { @settings.close_account(deletion_log: @log) }

    assert Identity::UserRegistered.exists?(@account.id)
    assert Identity::Session.exists?(@session.id)
  end

  test "reuses a verified record after a previously committed upload" do
    @client.stub_responses(:put_object, "ObjectLockedByBucketPolicy")
    @client.stub_responses(:get_object, body: JSON.generate(account_id: @account.deletion_replay_id, recorded_at: Time.current.iso8601))

    @settings.close_account(deletion_log: @log)

    assert_not Identity::UserRegistered.exists?(@account.id)
  end

  test "validates the full log before replay and skips accounts already purged" do
    Community::Membership::ManageProfile.new(community_user: @account.community_user).change_community_username(community_username: "Former_Member")
    key = "account-deletions/v1/recovery/#{@account.deletion_replay_id}.json"
    @client.stub_responses(:list_objects_v2, contents: [ { key: }, { key: "account-deletions/v1/recovery/invalid.json" } ])
    @client.stub_responses(:get_object, body: JSON.generate(account_id: @account.deletion_replay_id, recorded_at: Time.current.iso8601))
    replay = Identity::AccountAdministration::ReplayAccountDeletions.new(deletion_log: @log)

    assert_raises(Identity::Errors::DeletionLogUnavailable) { replay.call }
    assert Identity::UserRegistered.exists?(@account.id)

    @client.stub_responses(:list_objects_v2, contents: [ { key: } ])
    assert_equal 1, replay.call
    assert_equal 0, replay.call
    assert_not Identity::Session.exists?(@session.id)
    assert_username_released
  end

  private

  def assert_username_released
    password = "a long test password"
    replacement = Identity::UserRegistered.create!(email_address: "replacement@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current)
    Community::Membership::SetUpProfile.call(user_id: replacement.id, displayed_version: Community::CodeOfConduct.current.version, accepted: true)
    Community::Membership::ManageProfile.new(community_user: replacement.community_user).change_community_username(community_username: "former_member")
    assert_equal "former_member", replacement.reload.community_user&.community_username
  end
end

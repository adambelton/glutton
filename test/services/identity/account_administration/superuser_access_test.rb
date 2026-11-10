require "test_helper"

module Identity
  class SuperuserAccessTest < ActiveSupport::TestCase
    setup do
      @actor = Identity::UserRegistered.create!(email_address: "operator@example.test", password: "a long password phrase",
        password_confirmation: "a long password phrase", email_confirmed_at: Time.current, superuser: true)
    end

    def account
      Identity::UserRegistered.create!(email_address: "superuser@example.test", password: "a long password phrase",
        password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    end

    test "explicit grant and revoke preserve credentials and sessions and reject repeats" do
      user = account
      authentication = Identity::Session.create!(user: user)
      assert_not user.superuser?
      assert_raises(Errors::SuperuserAlreadyRevoked) { AccountAdministration::RevokeSuperuser.call(user_id: user.id, actor_user_id: @actor.id) }
      assert_equal user, AccountAdministration::GrantSuperuser.call(user_id: user.id, actor_user_id: @actor.id)
      assert user.reload.superuser?
      assert_raises(Errors::SuperuserAlreadyGranted) { AccountAdministration::GrantSuperuser.call(user_id: user.id, actor_user_id: @actor.id) }
      assert_equal user, AccountAdministration::RevokeSuperuser.call(user_id: user.id, actor_user_id: @actor.id)
      assert_not user.reload.superuser?
      assert authentication.active?
      assert user.authenticate("a long password phrase")
      assert_equal "superuser@example.test", user.email_address
    end

    test "unsupported and missing identities reject both operations" do
      freeze_time
      guest = Identity::UserGuest.create!
      deleted = Identity::UserDeleted.create!
      [ guest, deleted ].each do |user|
        assert_not user.superuser?
        assert_raises(Errors::SuperuserUnavailable) { user.grant_superuser!(actor: @actor) }
        assert_raises(Errors::SuperuserUnavailable) { user.revoke_superuser!(actor: @actor) }
      end
      travel Identity::UserGuest::EXPIRY_DURATION
      [ guest.id, deleted.id, -1 ].each do |user_id|
        assert_raises(Errors::SuperuserUnavailable) { AccountAdministration::GrantSuperuser.call(user_id:, actor_user_id: @actor.id) }
        assert_raises(Errors::SuperuserUnavailable) { AccountAdministration::RevokeSuperuser.call(user_id:, actor_user_id: @actor.id) }
      end
      assert_not guest.reload.superuser?
    end

    test "operations load authoritative state even when caller holds a stale account" do
      user = account
      AccountAdministration::GrantSuperuser.call(user_id: user.id, actor_user_id: @actor.id)
      assert_not user.superuser?
      AccountAdministration::RevokeSuperuser.call(user_id: user.id, actor_user_id: @actor.id)
      assert_not user.reload.superuser?
      user.destroy!
      assert_raises(Errors::SuperuserUnavailable) { AccountAdministration::GrantSuperuser.call(user_id: user.id, actor_user_id: @actor.id) }
      assert_raises(Errors::SuperuserUnavailable) { AccountAdministration::RevokeSuperuser.call(user_id: user.id, actor_user_id: @actor.id) }
    end

    test "only current superusers can authorize grants and revocations including direct model actions" do
      user = account
      guest = Identity::UserGuest.create!
      deleted = Identity::UserDeleted.create!
      [ user, guest, deleted ].each do |actor|
        assert_raises(Errors::SuperuserRequired) { AccountAdministration::GrantSuperuser.call(user_id: user.id, actor_user_id: actor.id) }
        assert_raises(Errors::SuperuserRequired) { AccountAdministration::RevokeSuperuser.call(user_id: user.id, actor_user_id: actor.id) }
        assert_raises(Errors::SuperuserRequired) { user.grant_superuser!(actor:) }
        assert_raises(Errors::SuperuserRequired) { user.revoke_superuser!(actor:) }
      end
      travel Identity::UserGuest::EXPIRY_DURATION do
        assert_raises(Errors::SuperuserRequired) { AccountAdministration::GrantSuperuser.call(user_id: user.id, actor_user_id: guest.id) }
      end
      assert_raises(Errors::SuperuserRequired) { AccountAdministration::GrantSuperuser.call(user_id: user.id, actor_user_id: -1) }
      assert_raises(Errors::SuperuserRequired) { AccountAdministration::RevokeSuperuser.call(user_id: user.id, actor_user_id: -1) }
      assert_not user.reload.superuser?
    end

    test "revoked and removed actors cannot use stale privilege or revoke another superuser" do
      user = account
      AccountAdministration::GrantSuperuser.call(user_id: user.id, actor_user_id: @actor.id)
      AccountAdministration::RevokeSuperuser.call(user_id: @actor.id, actor_user_id: @actor.id)
      assert @actor.superuser?
      assert_raises(Errors::SuperuserRequired) { AccountAdministration::RevokeSuperuser.call(user_id: user.id, actor_user_id: @actor.id) }
      @actor.destroy!
      assert_raises(Errors::SuperuserRequired) { AccountAdministration::RevokeSuperuser.call(user_id: user.id, actor_user_id: @actor.id) }
      assert user.reload.superuser?
    end

    test "storage requires clearing superuser privilege when anonymizing a deleted account" do
      # Explicit storage-contract test: deletion workflow is not implemented yet.
      deleted_attributes = { type: "UserDeleted", email_address: nil, password_digest: nil, email_confirmed_at: nil }
      error = assert_raises(ActiveRecord::StatementInvalid) do
        Identity::User.transaction(requires_new: true) { @actor.update_columns(deleted_attributes) }
      end
      assert_includes error.message, "only_registered_users_can_be_superusers"
      assert @actor.reload.superuser?

      @actor.update_columns(deleted_attributes.merge(superuser: false))
      deleted_user = Identity::User.find(@actor.id)
      assert_not deleted_user.superuser?
      assert_not deleted_user.active?
      assert_raises(Errors::SuperuserRequired) { AccountAdministration::GrantSuperuser.call(user_id: account.id, actor_user_id: deleted_user.id) }
    end

    test "storage and model validation restrict permission to registered accounts" do
      [ Identity::UserGuest, Identity::UserDeleted ].each do |model|
        assert_not model.new(superuser: true).valid?
        error = assert_raises(ActiveRecord::StatementInvalid) do
          Identity::User.transaction(requires_new: true) do
            Identity::User.insert_all!([ { type: model.sti_name, superuser: true,
              created_at: Time.current, updated_at: Time.current } ])
          end
        end
        assert_includes error.message, "only_registered_users_can_be_superusers"
      end
      user = account
      error = assert_raises(ActiveRecord::NotNullViolation) do
        Identity::User.transaction(requires_new: true) { user.update_columns(superuser: nil) }
      end
      assert_includes error.message, "superuser"
    end
  end
end

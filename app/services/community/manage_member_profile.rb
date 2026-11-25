module Community
  class ManageMemberProfile
    def initialize(user_id:)
      @settings = Identity::AccountAdministration::ManageRegisteredAccount.new(user_id:)
    end

    def change_username(community_username:)
      @settings.change_community_username(community_username:) { |account| PreviewAccess.require!(user: account) }
    end

    def choose_avatar(preset:)
      @settings.choose_community_avatar(preset:) { |account| PreviewAccess.require!(user: account) }
    end
  end
end

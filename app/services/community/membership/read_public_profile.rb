module Community
  module Membership
    class ReadPublicProfile
      def self.call(id:, viewer:, lock: false)
        Access.require!(user: viewer)
        profiles = CommunityUser.all
        profiles = profiles.lock if lock
        profile = profiles.find(id)
        raise ActiveRecord::RecordNotFound unless profile.public_identity?

        profile
      end
    end
  end
end

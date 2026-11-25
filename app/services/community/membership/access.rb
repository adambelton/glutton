module Community
  module Membership
    class Access
      def self.allowed?(user:)
        user.can_view_account?
      end

      def self.require!(user:)
        raise Errors::MembershipRequired unless allowed?(user:)
      end
    end
  end
end

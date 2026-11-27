module Community
  module Membership
    class Access
      def self.allowed?(user:)
        user.can_view_account?
      end

      def self.require!(user:)
        raise Errors::MembershipRequired unless allowed?(user:)
      end

      def self.suspended?(user:)
        allowed?(user:) && suspended_account?(user.id)
      end

      def self.participation_allowed?(user:)
        allowed?(user:) && !suspended_account?(user.id)
      end

      def self.require_participation!(user:)
        require!(user:)
        raise Errors::ParticipationSuspended if suspended_account?(user.id)
      end

      def self.suspended_account?(user_id)
        Suspension.active.exists?(member_id: user_id)
      end
      private_class_method :suspended_account?
    end
  end
end

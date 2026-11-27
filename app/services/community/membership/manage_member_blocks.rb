module Community
  module Membership
    class ManageMemberBlocks
      def self.block(user_id:, member_id:)
        with_accounts(user_id:, member_id:) do |actor, member|
          actor.block_member!(member:)
        end
      end

      def self.unblock(user_id:, member_id:)
        with_accounts(user_id:, member_id:) do |actor, member|
          actor.unblock_member!(member:)
        end
      end

      def self.with_accounts(user_id:, member_id:)
        MemberBlock.transaction do
          accounts = Identity::UserRegistered.where(id: [ user_id, member_id ]).order(:id).lock.index_by(&:id)
          actor = accounts[user_id]
          raise Errors::MembershipRequired unless actor.present?

          Access.require!(user: actor)
          actor_profile = actor.community_user
          member_profile = accounts[member_id]&.community_user
          raise Errors::MemberBlockUnavailable unless actor_profile.present? && member_profile.present?

          yield actor_profile, member_profile
        end
      end

      private_class_method :with_accounts
    end
  end
end

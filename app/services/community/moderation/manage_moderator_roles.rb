module Community
  module Moderation
    class ManageModeratorRoles
      def self.grant(actor_id:, member_id:)
        with_registered_members(actor_id:, member_id:) do |actor, member|
          ModeratorRole.grant!(member:, actor:)
        end
      end

      def self.revoke(actor_id:, member_id:, role_id:)
        with_registered_members(actor_id:, member_id:) do |actor, member|
          role = ModeratorRole.active.find_by(id: role_id, member:)
          raise Errors::ModeratorRoleUnavailable unless role.present?

          role.revoke!(actor:)
        end
      end

      def self.with_registered_members(actor_id:, member_id:)
        ModeratorRole.transaction(requires_new: true) do
          members = Identity::UserRegistered.where(id: [ actor_id, member_id ]).order(:id).lock.index_by(&:id)
          actor = members[actor_id]
          raise Errors::ModerationAccessDenied unless actor.present? && Access.manage_roles?(user: actor)

          member = members[member_id]
          raise Identity::Errors::Unavailable unless member.present?

          yield actor, member
        end
      end
      private_class_method :with_registered_members
    end
  end
end

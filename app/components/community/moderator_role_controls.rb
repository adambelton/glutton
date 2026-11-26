module Community
  class ModeratorRoleControls < Shared::Base
    def initialize(member:)
      @member = member
    end

    def view_template
      return unless Membership::Access.allowed?(user: @member)

      role = ModeratorRole.active.find_by(member: @member)
      path = admin_user_community_moderator_role_path(@member)
      section(class: "admin-detail-section", aria: { labelledby: "community-moderator-role-heading" }) do
        h2(id: "community-moderator-role-heading") { t("community.moderation.role_heading") }
        if role.present?
          render Shared::ActionForm.new(url: path, method: :delete, params: { role_id: role.id }) do
            render Shared::GhostButton.new(type: :submit) { t("community.moderation.revoke") }
          end
        else
          render Shared::ActionForm.new(url: path) do
            render Shared::PrimaryButton.new(type: :submit) { t("community.moderation.grant") }
          end
        end
      end
    end
  end
end

module Community
  class ModeratorRolesController < ApplicationController
    before_action :require_role_management

    rescue_from Errors::ModerationAccessDenied do
      head :forbidden
    end

    rescue_from Identity::Errors::Unavailable do
      head :not_found
    end

    rescue_from Errors::ModeratorRoleUnavailable do
      redirect_to admin_user_path(params[:user_id]), status: :see_other, alert: t("community.moderation.role_unavailable")
    end

    def create
      member_id = record_id(params[:user_id])
      return head :not_found unless member_id.present?

      Moderation::ManageModeratorRoles.grant(actor_id: current_user.id, member_id:)
      redirect_to admin_user_path(member_id), status: :see_other, notice: t("community.moderation.granted")
    end

    def destroy
      member_id = record_id(params[:user_id])
      return head :not_found unless member_id.present?

      role_id = record_id(params[:role_id])
      return head :bad_request unless role_id.present?

      Moderation::ManageModeratorRoles.revoke(actor_id: current_user.id, member_id:, role_id:)
      redirect_to admin_user_path(member_id), status: :see_other, notice: t("community.moderation.revoked")
    end

    private

    def require_role_management
      head :forbidden unless Moderation::Access.manage_roles?(user: current_user)
    end

    def record_id(value)
      value.to_i if value.is_a?(String) && value.match?(/\A[1-9]\d{0,17}\z/)
    end
  end
end

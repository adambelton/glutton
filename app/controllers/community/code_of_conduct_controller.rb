module Community
  class CodeOfConductController < ApplicationController
    allow_unauthenticated_access only: :show
    before_action :require_member_access, only: :accept

    def show
      render Views::Community::CodeOfConduct.new(code: CodeOfConduct.current)
    end

    def accept
      Membership::SetUpProfile.call(user_id: current_user.id, displayed_version: params[:code_version], accepted: params[:accepted] == "1")
      redirect_to account_community_path, notice: t("community.conduct.accepted"), status: :see_other
    rescue Errors::MembershipRequired
      head :forbidden
    rescue Errors::CodeOfConductChanged
      redirect_to account_community_path, alert: t("community.conduct.version_changed"), status: :see_other
    rescue Errors::ExplicitAcceptanceRequired
      redirect_to account_community_path, alert: t("community.conduct.acceptance_required"), status: :see_other
    end

    private

    def require_member_access
      head :forbidden unless Membership::Access.allowed?(user: current_user)
    end
  end
end

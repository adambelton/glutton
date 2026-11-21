module Community
  class OnboardingController < ApplicationController
    before_action :require_preview_access

    def show
      render Views::Community::Onboarding.new
    end

    def accept
      AcceptCodeOfConduct.call(user_id: current_user.id, displayed_version: params[:code_version], accepted: params[:accepted] == "1")
      redirect_to return_path, notice: t("community.conduct.accepted"), status: :see_other
    rescue Errors::MembershipRequired
      head :forbidden
    rescue Errors::CodeOfConductChanged
      redirect_to return_path, alert: t("community.conduct.version_changed"), status: :see_other
    rescue Errors::ExplicitAcceptanceRequired
      redirect_to return_path, alert: t("community.conduct.acceptance_required"), status: :see_other
    end

    private

    def require_preview_access
      head :forbidden unless PreviewAccess.allowed?(user: current_user)
    end

    def return_path
      params[:source] == "account" ? account_community_path : community_path
    end
  end
end

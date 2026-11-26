module Community
  class ModerationReportsController < ApplicationController
    rescue_from Errors::ModerationAccessDenied, with: -> { head :forbidden }
    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
    rescue_from Errors::ReportAlreadyEscalated do
      redirect_to community_moderation_report_path(params[:id]), alert: t("community.reports.already_escalated"), status: :see_other
    end

    def show
      report = Reporting::BrowseReports.detail(viewer: current_user, report_id: params[:id])
      render Views::Community::ModerationReport.new(report:)
    end

    def escalate
      Reporting::EscalateReport.call(actor_id: current_user.id, report_id: params[:id])
      redirect_to community_moderation_report_path(params[:id]), notice: t("community.reports.escalated"), status: :see_other
    end
  end
end

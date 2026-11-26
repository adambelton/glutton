module Community
  class ModerationReportsController < ApplicationController
    rescue_from Errors::ModerationAccessDenied, with: -> { head :forbidden }
    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
    rescue_from Errors::ReportAlreadyEscalated do
      redirect_to community_moderation_report_path(params[:id]), alert: t("community.reports.already_escalated"), status: :see_other
    end

    rescue_from Errors::ReportAlreadyResolved do
      redirect_to community_moderation_report_path(params[:id]), alert: t("community.reports.resolution.already_resolved"), status: :see_other
    end
    rescue_from Errors::ReportReviewChanged do
      redirect_to community_moderation_report_path(params[:id]), alert: t("community.reports.resolution.review_changed"), status: :see_other
    end

    def show
      report = Reporting::BrowseReports.detail(viewer: current_user, report_id: params[:id])
      render Views::Community::ModerationReport.new(report:)
    end

    def escalate
      Reporting::EscalateReport.call(actor_id: current_user.id, report_id: params[:id])
      redirect_to community_moderation_report_path(params[:id]), notice: t("community.reports.escalated"), status: :see_other
    end

    def resolve
      fields = params.expect(resolution: [ :expected_status, :outcome, :summary ])
      expected_status, outcome, summary = fields.values_at(:expected_status, :outcome, :summary)
      resolution = Reporting::ResolveReport.call(actor_id: current_user.id, report_id: params[:id],
        expected_status:, outcome:, summary:)
      if resolution.errors.any?
        report = Reporting::BrowseReports.detail(viewer: current_user, report_id: resolution.id)
        return render Views::Community::ModerationReport.new(report:, resolution:), status: :unprocessable_content
      end

      redirect_to community_moderation_report_path(resolution), notice: t("community.reports.resolution.saved"), status: :see_other
    end
  end
end

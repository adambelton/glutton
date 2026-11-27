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
    rescue_from Errors::ReportSourceChanged do
      redirect_to community_moderation_report_path(params[:id]), alert: t("community.reports.resolution.source_changed"), status: :see_other
    end
    rescue_from Errors::ReportDeletionUnavailable do
      redirect_to community_moderation_report_path(params[:id]), alert: t("community.reports.resolution.deletion_unavailable"), status: :see_other
    end

    def index
      search = CollectionSearchParameters.parse(query: "", page: params.fetch(:page, "1"), max_digits: 6)
      state = params.fetch(:state, "open")
      return head :bad_request unless search.present? && Reporting::BrowseReports::STATES.key?(state)

      queue_page = Reporting::BrowseReports.page(viewer: current_user, number: search.page, state:)
      return redirect_to community_moderation_reports_path(state:) if search.page > queue_page.total_pages

      render Views::Community::Moderation.new(queue_page:, state:)
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
      fields = params.expect(resolution: [ :expected_status, :outcome, :action, :summary, :revision ])
      expected_status, outcome, action, summary, revision = fields.values_at(:expected_status, :outcome, :action, :summary, :revision)
      outcome = nil unless outcome.is_a?(String)
      action = nil unless action.is_a?(String)
      summary = nil unless summary.is_a?(String)
      revision = nil unless revision.is_a?(String)
      resolution = Reporting::ResolveReport.call(actor_id: current_user.id, report_id: params[:id],
        expected_status:, outcome:, action:, summary:, revision:)
      if resolution.errors.any?
        report = Reporting::BrowseReports.detail(viewer: current_user, report_id: resolution.id)
        return render Views::Community::ModerationReport.new(report:, resolution:), status: :unprocessable_content
      end

      redirect_to community_moderation_report_path(resolution), notice: t("community.reports.resolution.saved"), status: :see_other
    end
  end
end

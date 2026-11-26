module Community
  class ReportsController < ApplicationController
    before_action :require_member_access
    before_action :validate_target_identifiers

    rescue_from Errors::MembershipRequired, with: -> { head :forbidden }
    rescue_from ActiveRecord::RecordNotFound, Errors::NominationUnavailable, Errors::ReportTargetUnavailable, with: -> { head :not_found }
    rescue_from Errors::ReportAlreadyOpen do
      redirect_to return_path, alert: t("community.reports.already_open"), status: :see_other
    end

    def new
      render_form(Report.new)
    end

    def create
      fields = params.expect(report: [ :reason, :explanation, :revision ])
      reason, explanation, revision = fields.values_at(:reason, :explanation, :revision)
      report = submission.submit(reporter_id: current_user.id, reason:, explanation:,
        revision: revision.is_a?(String) ? revision : nil)
      if report.persisted?
        redirect_to return_path, notice: t("community.reports.submitted"), status: :see_other
      else
        render_form(report, status: :unprocessable_content)
      end
    rescue Errors::ReportTargetChanged
      report = Report.new(reason:, explanation:)
      report.errors.add(:base, t("community.reports.target_changed"))
      render_form(report, status: :unprocessable_content)
    end

    private

    def require_member_access
      Membership::Access.require!(user: current_user)
    end

    def validate_target_identifiers
      ids = target_identifiers.values
      raise ActionController::BadRequest unless ids.all? { |id| RecordId.valid?(id) }
    end

    def submission
      @submission ||= Reporting::ReportSubmission.new(**target_identifiers)
    end

    def target_identifiers
      request.path_parameters.slice(:post_id, :comment_id)
    end

    def render_form(report, status: :ok)
      reportable = submission.target(viewer: current_user)
      evidence = reportable.reportable_attributes
      render Views::Community::NewReport.new(report:, evidence:, revision: submission.revision(reportable:, evidence:),
        reasons: submission.reasons(reportable:), form_path:, return_path:), status:
    end

    def form_path
      post_id, comment_id = target_identifiers.values_at(:post_id, :comment_id)
      comment_id.present? ? community_post_comment_report_path(post_id, comment_id) : community_post_report_path(post_id)
    end

    def return_path
      post_id, comment_id = target_identifiers.values_at(:post_id, :comment_id)
      options = comment_id.present? ? { reply: comment_id, anchor: "comment-#{comment_id}" } : {}
      community_post_path(post_id, **options)
    end
  end
end

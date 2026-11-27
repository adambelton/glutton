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
      report = report_workflow.submit(reporter_id: current_user.id, reason:, explanation:,
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

    def report_workflow
      identifiers = target_identifiers.transform_values(&:to_i)
      if identifiers.key?(:member_id)
        Reporting::SubmitProfileReport.new(**identifiers)
      else
        Reporting::SubmitPostReport.new(**identifiers)
      end
    end

    def target_identifiers
      request.path_parameters.slice(:post_id, :comment_id, :member_id)
    end

    def render_form(report, status: :ok)
      reportable = report_workflow.target(viewer: current_user)
      evidence = Reporting::ReportSubmission.evidence_for(reportable:)
      render Views::Community::NewReport.new(report:, evidence:, revision: Reporting::ReportSubmission.revision(reportable:, evidence:),
        reasons: reportable.report_reasons, form_path:, return_path:), status:
    end

    def form_path
      return community_member_report_path(target_identifiers[:member_id]) if target_identifiers[:member_id].present?

      post_id, comment_id = target_identifiers.values_at(:post_id, :comment_id)
      comment_id.present? ? community_post_comment_report_path(post_id, comment_id) : community_post_report_path(post_id)
    end

    def return_path
      return community_member_path(target_identifiers[:member_id]) if target_identifiers[:member_id].present?

      post_id, comment_id = target_identifiers.values_at(:post_id, :comment_id)
      options = comment_id.present? ? { reply: comment_id, anchor: "comment-#{comment_id}" } : {}
      community_post_path(post_id, **options)
    end
  end
end

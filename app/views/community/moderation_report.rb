module Views
  module Community
    class ModerationReport < ::Views::Base
      def initialize(report:, resolution: nil)
        @report, @resolution = report, resolution
      end

      def view_template
        page(title: t("community.reports.identifier", id: @report.id), heading_outside_card: true,
          back_to: community_moderation_path(state: (@report.status unless @report.pending?)), back_label: t("community.reports.back")) do
          div(class: "community-report-review") do
            if @report.resolved?
              resolution_details
              report_status
            else
              account_snapshots
              reportable_details
              report_status
              render ::Community::ReportResolutionForm.new(report: @report, draft: @resolution)
            end
          end
        end
      end

      private

      def reportable_details
        section(class: "community-report-section") do
          h2 { t("community.reports.reportable.heading") }
          dl(class: "community-report-metadata") do
            metadata(t("community.reports.reportable.type"), @report.reportable_type)
            metadata(t("community.reports.reportable.id"), @report.reportable_id)
          end
          div(class: "community-report-comparison community-report-columns") do
            section(class: "community-report-section") do
              h3 { t("community.reports.reported_content") }
              render ::Community::ReportEvidence.new(evidence: @report.evidence)
            end
            section(class: "community-report-section") do
              h3 { t("community.reports.current_content") }
              current_evidence = @report.current_evidence
              if current_evidence.present?
                render ::Community::ReportEvidence.new(evidence: current_evidence)
              else
                p(class: "community-report-excerpt") { t("community.reports.source_deleted") }
              end
            end
          end
        end
      end

      def report_status
        section(class: "community-report-section") do
          h2 { t("community.reports.status") }
          dl(class: "community-report-metadata") do
            metadata(t("community.reports.status"), t("community.reports.states.#{@report.status}"))
            metadata(t("community.reports.submitted_at"), I18n.l(@report.created_at, format: :long))
            metadata(t("community.reports.reason"), t("community.reports.reasons.#{@report.reason}"))
          end
          evidence_section(t("community.reports.explanation"), @report.explanation) if @report.explanation.present?
          escalate_action if @report.pending?
        end
      end

      def metadata(label, value)
        dt { label }
        dd { value.present? ? value.to_s : t("community.reports.unavailable") }
      end

      def resolution_details
        section do
          h2 { t("community.reports.resolution.decision") }
          dl(class: "community-report-metadata") do
            metadata(t("community.reports.resolution.outcome"), t("community.reports.resolution.outcomes.#{@report.resolution_outcome}"))
            if @report.accepted?
              dt { t("community.reports.resolution.action_taken") }
              dd { render ::Community::ReportResolutionAction.new(report: @report) }
            end
            dt { t("community.reports.resolution.reviewed_at") }
            dd { I18n.l(@report.resolved_at, format: :long) }
            dt { t("community.reports.resolution.reviewed_by") }
            moderator = @report.resolved_by
            dd do
              if moderator.present?
                plain(moderator.community_user&.community_username.presence || t("community.reports.resolution.moderator_account", id: moderator.id))
              else
                plain t("community.reports.resolution.moderator_unavailable")
              end
            end
          end
        end
        evidence_section(t("community.reports.resolution.summary"), @report.resolution_summary)
      end

      def evidence_section(heading, text)
        section do
          h2 { heading }
          p(class: "community-curation-prompt") { text }
        end
      end

      def escalate_action
        render Shared::ActionForm.new(url: escalate_community_moderation_report_path(@report), method: :patch) do
          render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button") { t("community.reports.escalate") }
        end
      end

      def account_snapshots
        section(class: "community-report-section") do
          h2 { t("community.reports.members") }
          div(class: "community-report-members community-report-columns") do
            %w[reporter reported_member].each do |role|
              account = @report.identity_snapshot[role]
              section(class: "community-report-excerpt") do
                h3 { t("community.reports.identities.#{role}") }
                if account.present?
                  dl(class: "community-report-metadata") do
                    account.each do |field, value|
                      metadata(t("community.reports.identities.#{field}"), value) if value.present?
                    end
                  end
                else
                  p { t("community.reports.unavailable") }
                end
              end
            end
          end
        end
      end
    end
  end
end

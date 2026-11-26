module Views
  module Community
    class ModerationReport < ::Views::Base
      def initialize(report:)
        @report = report
      end

      def view_template
        page(title: t("community.reports.identifier", id: @report.id), heading_outside_card: true,
          back_to: community_moderation_path, back_label: t("community.reports.back")) do
          p { t("community.reports.states.#{@report.status}") }
          p(class: "muted") { I18n.l(@report.created_at, format: :long) }
          p { t("community.reports.reasons.#{@report.reason}") }
          p(class: "muted") { t("community.reports.parts.#{@report.part}") }
          evidence_section(t("community.reports.reported_version"), @report.evidence_text)
          current_text = @report.current_text
          if current_text != @report.evidence_text
            evidence_section(t("community.reports.current_version"), current_text || t("community.reports.source_unavailable"))
          end
          if @report.explanation.present?
            evidence_section(t("community.reports.explanation"), @report.explanation)
          end
          account_snapshots
          escalate_action if @report.pending?
        end
      end

      private

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
        @report.identity_snapshot.each do |role, account|
          section do
            h2 { t("community.reports.identities.#{role}") }
            dl do
              account.each do |field, value|
                next unless value.present?

                dt { t("community.reports.identities.#{field}") }
                dd { value.to_s }
              end
            end
          end
        end
      end
    end
  end
end

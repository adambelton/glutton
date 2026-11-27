module Community
  module Reporting
    class ReportSubmission
      def self.evidence_for(reportable:)
        evidence = reportable&.reportable_attributes
        raise Errors::ReportTargetUnavailable unless evidence.present?

        evidence
      end

      def self.revision(reportable:, evidence:)
        verifier.generate(reportable.reportable_revision(evidence:))
      end

      # The caller authorises the target and holds the required locks through this write.
      def self.call(reporter:, reportable:, reason:, explanation:, revision:)
        evidence = evidence_for(reportable:)
        raise Errors::ReportAlreadyOpen if reportable.reports.unresolved.exists?(reporter:)
        unless revision.present? && verifier.verified(revision) == reportable.reportable_revision(evidence:)
          raise Errors::ReportTargetChanged
        end

        Report.capture(reportable:, reporter:, evidence:, reason:, explanation:)
      end

      def self.verifier
        Rails.application.message_verifier(:community_report_revision)
      end
      private_class_method :verifier
    end
  end
end

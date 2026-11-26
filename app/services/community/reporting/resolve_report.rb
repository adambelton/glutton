module Community
  module Reporting
    class ResolveReport
      def self.call(actor_id:, report_id:, expected_status:, outcome:, summary:, action:, revision: nil)
        Report.transaction do
          moderator = Identity::UserRegistered.lock.find_by(id: actor_id)
          raise Errors::ModerationAccessDenied unless moderator.present?
          Report.require_review_access!(moderator:)

          report = Report.find(report_id)
          deletion_requested = outcome == Report::ACCEPTED_OUTCOME && Reportable.deletion_action?(action)

          # Source deletion triggers also lock reports. Take the source lock first.
          source = lock_source(report.reportable) if deletion_requested
          report.lock!
          if deletion_requested
            raise Errors::ReportAlreadyResolved if report.resolved?
            report.require_reviewed_source!(source:, revision:)
            raise Errors::ReportDeletionUnavailable unless source.report_deletion_actions.include?(action)
          end

          resolution = report.resolve(moderator:, expected_status:, outcome:, summary:, action:)
          source.delete_reported_content!(moderator:, action:) if deletion_requested && resolution.errors.empty?
          resolution
        end
      end

      def self.lock_source(source)
        source&.lock_for_report_deletion!
      rescue ActiveRecord::RecordNotFound
        nil
      end
      private_class_method :lock_source
    end
  end
end

module Community
  module Reporting
    class ResolveReport
      def self.call(actor_id:, report_id:, expected_status:, outcome:, summary:)
        Report.transaction do
          moderator = Identity::UserRegistered.lock.find_by(id: actor_id)
          raise Errors::ModerationAccessDenied unless moderator.present?

          report = Report.lock.find_by(id: report_id)
          return report.resolve(moderator:, expected_status:, outcome:, summary:) if report.present?

          Report.require_review_access!(moderator:)
          raise ActiveRecord::RecordNotFound
        end
      end
    end
  end
end

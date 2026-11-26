module Community
  module Reporting
    class EscalateReport
      def self.call(actor_id:, report_id:)
        Report.transaction do
          moderator = Identity::UserRegistered.lock.find_by(id: actor_id)
          raise Errors::ModerationAccessDenied unless moderator.present?

          report = Report.lock.find_by(id: report_id)
          return report.escalate!(moderator:) if report.present?

          Report.require_escalation_access!(moderator:)
          raise ActiveRecord::RecordNotFound
        end
      end
    end
  end
end

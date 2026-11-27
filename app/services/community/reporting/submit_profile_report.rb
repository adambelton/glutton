module Community
  module Reporting
    class SubmitProfileReport
      def initialize(member_id:)
        @member_id = member_id
      end

      def target(viewer:, lock: false)
        Membership::ReadPublicProfile.call(id: @member_id, viewer:, lock:)
      end

      def submit(reporter_id:, reason:, explanation:, revision:)
        Report.transaction do
          accounts = Identity::UserRegistered.where(id: [ reporter_id, @member_id ]).order(:id).lock.to_a
          reporter = accounts.find { |account| account.id == reporter_id }
          raise Errors::MembershipRequired unless reporter.present?

          reportable = target(viewer: reporter, lock: true)
          ReportSubmission.call(reporter:, reportable:, reason:, explanation:, revision:)
        end
      end
    end
  end
end

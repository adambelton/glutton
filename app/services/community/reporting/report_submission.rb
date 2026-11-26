module Community
  module Reporting
    class ReportSubmission
      def initialize(post_id:, comment_id: nil)
        @post_id, @comment_id = post_id, comment_id
      end

      def target(viewer:, lock: false)
        post = Posts::ReadPost.call(id: @post_id, viewer:, lock:)
        reportable = @comment_id.present? ? post.discussion_comment(@comment_id).content : post
        reportable.lock! if lock && @comment_id.present? && reportable.present?
        raise Errors::ReportTargetUnavailable unless reportable.present? && reportable.reportable_attributes.present?

        reportable
      end

      def revision(reportable:, evidence:)
        verifier.generate(fingerprint(reportable:, evidence:))
      end

      def submit(reporter_id:, reason:, explanation:, revision:)
        Report.transaction do
          reporter = Identity::UserRegistered.lock.find_by(id: reporter_id)
          raise Errors::MembershipRequired unless reporter.present?

          reportable = target(viewer: reporter, lock: true)
          if reportable.reports.unresolved.exists?(reporter:)
            raise Errors::ReportAlreadyOpen
          end

          evidence = reportable.reportable_attributes
          unless revision.present? && verifier.verified(revision) == fingerprint(reportable:, evidence:)
            raise Errors::ReportTargetChanged
          end

          Report.capture(reportable:, reporter:, evidence:, reason: reasons(reportable:).find { |supported| supported == reason }, explanation:)
        end
      end

      def reasons(reportable:)
        reportable.spoiler_free? ? Report::REASONS : Report::REASONS.excluding("spoilers")
      end

      private

      def verifier
        Rails.application.message_verifier(:community_report_revision)
      end

      def fingerprint(reportable:, evidence:)
        Digest::SHA256.hexdigest([ reportable.class.polymorphic_name, reportable.id, evidence.sort ].to_json)
      end
    end
  end
end

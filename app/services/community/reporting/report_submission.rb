module Community
  module Reporting
    class ReportSubmission
      def initialize(post_id:, comment_id: nil)
        @post_id, @comment_id = post_id, comment_id
      end

      def target(viewer:, lock: false)
        post = Posts::ReadPost.call(id: @post_id, viewer:, lock:)
        reportable = @comment_id.present? ? post.discussion_comment(@comment_id).content : post
        raise Errors::ReportTargetUnavailable unless reportable.present? && reportable.reportable_parts.present?

        reportable
      end

      def revisions(reportable:, parts:)
        parts.to_h { |part, text| [ part, verifier.generate(fingerprint(reportable:, part:, text:)) ] }
      end

      def submit(reporter_id:, part:, reason:, explanation:, revision:)
        Report.transaction do
          reporter = Identity::UserRegistered.lock.find_by(id: reporter_id)
          raise Errors::MembershipRequired unless reporter.present?

          reportable = target(viewer: reporter, lock: true)
          if reportable.reports.exists?(reporter:, part:, status: %w[pending escalated])
            raise Errors::ReportAlreadyOpen
          end

          text = reportable.reportable_text(part:)
          unless text.present? && revision.present? && verifier.verified(revision) == fingerprint(reportable:, part:, text:)
            raise Errors::ReportTargetChanged
          end

          Report.capture(reportable:, reporter:, part:, reason: reasons(reportable:).find { |supported| supported == reason }, explanation:)
        end
      end

      def reasons(reportable:)
        reportable.spoiler_free? ? Report::REASONS : Report::REASONS.excluding("spoilers")
      end

      private

      def verifier
        Rails.application.message_verifier(:community_report_revision)
      end

      def fingerprint(reportable:, part:, text:)
        Digest::SHA256.hexdigest([ reportable.class.polymorphic_name, reportable.id, part, text ].to_json)
      end
    end
  end
end

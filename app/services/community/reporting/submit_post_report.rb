module Community
  module Reporting
    class SubmitPostReport
      def initialize(post_id:, comment_id: nil)
        @post_id = post_id
        @comment_id = comment_id
      end

      def target(viewer:, lock: false)
        post = Posts::ReadPost.call(id: @post_id, viewer:, lock:)
        return post unless @comment_id.present?

        content = post.discussion_comment(@comment_id).content
        content&.lock! if lock
        Membership::MemberVisibility.require_visible!(viewer_id: viewer.id, blockable: content)
        content
      end

      def submit(reporter_id:, reason:, explanation:, revision:)
        Report.transaction do
          reporter = Identity::UserRegistered.lock.find_by(id: reporter_id)
          raise Errors::MembershipRequired unless reporter.present?

          reportable = target(viewer: reporter, lock: true)
          ReportSubmission.call(reporter:, reportable:, reason:, explanation:, revision:)
        end
      end
    end
  end
end

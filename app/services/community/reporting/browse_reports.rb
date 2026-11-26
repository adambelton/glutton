module Community
  module Reporting
    class BrowseReports
      PAGE_SIZE = 20

      def self.page(viewer:, number:)
        require_access!(viewer:)
        reports = Report.order(priority: :desc, created_at: :asc, id: :asc)
        CountedPage.load(reports, number:, page_size: PAGE_SIZE)
      end

      def self.detail(viewer:, report_id:)
        require_access!(viewer:)
        Report.find(report_id)
      end

      def self.require_access!(viewer:)
        raise Errors::ModerationAccessDenied unless Moderation::Access.review?(user: viewer)
      end
      private_class_method :require_access!
    end
  end
end

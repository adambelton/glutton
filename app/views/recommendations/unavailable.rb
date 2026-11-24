module Views
  module Recommendations
    class Unavailable < ::Views::Base
      def initialize(message:)
        @message = message
      end

      def view_template
        page(title: t("recommendations.title"), heading_outside_card: true,
          back_to: recommendation_path, back_label: t("recommendations.return")) do
          p(role: "alert") { @message }
        end
      end
    end
  end
end

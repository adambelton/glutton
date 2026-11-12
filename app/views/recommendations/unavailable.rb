module Views
  module Recommendations
    class Unavailable < ::Views::Base
      def initialize(message:)
        @message = message
      end

      def view_template
        page(title: t("recommendations.title"), heading_outside_card: true) do
          p(role: "alert") { @message }
          text_link(t("recommendations.return"), recommendation_path)
        end
      end
    end
  end
end

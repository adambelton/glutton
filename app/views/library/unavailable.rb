module Views
  module Library
    class Unavailable < ::Views::Base
      def initialize(error:)
        @error = error
      end

      def view_template
        page(title: t("library.browser.title"), class: "library-page", heading_outside_card: true,
          back_to: library_path, back_label: t("library.browser.return")) do
          p(role: "alert") { @error }
        end
      end
    end
  end
end

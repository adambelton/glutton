module Views
  module Library
    class Unavailable < ::Views::Base
      def initialize(error:)
        @error = error
      end

      def view_template
        page(title: t("library.browser.title"), class: "library-page") do
          p(role: "alert") { @error }
          text_link(t("library.browser.return"), library_path)
        end
      end
    end
  end
end

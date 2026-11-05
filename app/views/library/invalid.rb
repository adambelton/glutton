module Views
  module Library
    class Invalid < ::Views::Base
      def view_template
        page(title: t("library.browser.title"), class: "library-page") do
          p { t("library.browser.invalid") }
          text_link(t("library.browser.return"), library_path)
        end
      end
    end
  end
end

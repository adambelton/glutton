module Views
  module Library
    class Invalid < ::Views::Base
      def view_template
        page(title: t("library.browser.title"), class: "library-page", heading_outside_card: true,
          back_to: library_path, back_label: t("library.browser.return")) do
          p { t("library.browser.invalid") }
        end
      end
    end
  end
end

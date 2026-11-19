module Views
  module Admin
    class Message < Base
      def initialize(key:)
        @key = key
      end

      def view_template
        dashboard(title: t("registry.errors.#{@key}.title")) do
          p { t("registry.errors.#{@key}.description") }
          a(href: root_path, class: "back-link") { t("registry.back_to_app") }
        end
      end
    end
  end
end

module Views
  module Registry
    class Message < Base
      def initialize(key:)
        @key = key
      end

      def view_template
        shell(title: t("errors.#{@key}.title")) do
          section(class: "registry-panel prose-panel") do
            p { t("errors.#{@key}.description") }
            a(href: root_path, class: "back-link") { t(:back_to_app) }
          end
        end
      end
    end
  end
end

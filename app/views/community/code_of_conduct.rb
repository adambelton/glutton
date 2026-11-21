module Views
  module Community
    class CodeOfConduct < ::Views::Base
      def initialize(code:)
        @code = code
      end

      def view_template
        scope = @code.translation_scope
        page(title: t("community.conduct.title"), narrow: true, pending_reminder: false, account_controls: false) do
          p(class: "muted") { t("community.conduct.version", version: @code.version) }
          p { t("#{scope}.intro") }
          %i[respect spoilers avatars moderation].each do |topic|
            section do
              h2 { t("#{scope}.#{topic}.title") }
              p { t("#{scope}.#{topic}.description") }
            end
          end
          section do
            h2 { t("#{scope}.copyright.title") }
            p { t("#{scope}.copyright.description") }
            text_link(t("#{scope}.copyright.email"), "mailto:#{t("#{scope}.copyright.email")}")
          end
        end
      end
    end
  end
end

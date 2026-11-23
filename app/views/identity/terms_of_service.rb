module Views
  module Identity
    class TermsOfService < ::Views::Base
      def initialize(terms:)
        @terms = terms
      end

      def view_template
        page(title: t("#{@terms.translation_scope}.title"), narrow: true, pending_reminder: false, account_controls: false) do
          p { t("#{@terms.translation_scope}.operator") }
          %i[service account acceptable_use changes terms_changes rights].each do |topic|
            section do
              h2 { t("#{@terms.translation_scope}.#{topic}.title") }
              p { t("#{@terms.translation_scope}.#{topic}.description") }
            end
          end
          p { text_link(t("identity.privacy_notice.title"), privacy_notice_path) }
        end
      end
    end
  end
end

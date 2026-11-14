module Views
  module Identity
    class TermsOfService < ::Views::Base
      def view_template
        page(title: t("identity.terms_of_service.title"), narrow: true, pending_reminder: false, account_controls: false) do
          p { t("identity.terms_of_service.version", version: ::Identity::TermsOfService::VERSION) }
          p { t("identity.terms_of_service.operator") }
          %i[service account acceptable_use changes rights].each do |topic|
            section do
              h2 { t("identity.terms_of_service.#{topic}.title") }
              p { t("identity.terms_of_service.#{topic}.description") }
            end
          end
          p { text_link(t("identity.privacy_notice.title"), privacy_notice_path) }
        end
      end
    end
  end
end

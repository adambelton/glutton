module Views
  module Identity
    class PrivacyNotice < ::Views::Base
      def view_template
        page(title: t("identity.privacy_notice.title"), narrow: true, pending_reminder: false, account_controls: false) do
          p { t("identity.privacy_notice.operator") }
          %i[data lawful_bases providers retention account_deletion backups rights].each do |topic|
            section do
              h2 { t("identity.privacy_notice.#{topic}.title") }
              p { t("identity.privacy_notice.#{topic}.description") }
            end
          end
        end
      end
    end
  end
end

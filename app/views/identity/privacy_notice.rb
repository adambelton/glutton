module Views
  module Identity
    class PrivacyNotice < ::Views::Base
      def view_template
        page(title: t("identity.privacy_notice.title"), narrow: true, pending_reminder: false, account_controls: false) do
          p { t("identity.privacy_notice.operator") }
          %i[data lawful_bases providers international_transfers retention account_deletion backups rights].each do |topic|
            section do
              h2 { t("identity.privacy_notice.#{topic}.title") }
              if topic == :providers
                ai_providers
                t("identity.privacy_notice.providers.paragraphs").each { |paragraph| p { paragraph } }
              elsif topic == :international_transfers
                t("identity.privacy_notice.#{topic}.paragraphs").each { |paragraph| p { paragraph } }
              else
                p { t("identity.privacy_notice.#{topic}.description") }
              end
            end
          end
        end
      end

      private

      def ai_providers
        h3(id: "ai-providers") { t("identity.privacy_notice.providers.ai_title") }
        p { t("identity.privacy_notice.providers.ai_intro") }
        dl do
          %i[typesafe openai].each do |provider|
            dt { strong { t("identity.privacy_notice.providers.#{provider}.name") } }
            dd { p { t("identity.privacy_notice.providers.#{provider}.description") } }
          end
        end
      end
    end
  end
end

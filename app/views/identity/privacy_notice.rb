module Views
  module Identity
    class PrivacyNotice < ::Views::Base
      def initialize(notice:)
        @notice = notice
      end

      def view_template
        page(title: notice_text("title"), narrow: true, pending_reminder: false, account_controls: false) do
          p { t("identity.privacy_notice.version", version: @notice.version) }
          p { notice_text("operator") }
          %i[data lawful_bases providers international_transfers retention account_deletion backups rights].each do |topic|
            section do
              h2 { notice_text("#{topic}.title") }
              if topic == :providers
                ai_providers
                notice_text("providers.paragraphs").each { |paragraph| p { paragraph } }
              elsif topic == :international_transfers
                notice_text("#{topic}.paragraphs").each { |paragraph| p { paragraph } }
              else
                p { notice_text("#{topic}.description") }
              end
            end
          end
        end
      end

      private

      def notice_text(key)
        t("#{@notice.translation_scope}.#{key}")
      end

      def ai_providers
        h3(id: "ai-providers") { notice_text("providers.ai_title") }
        p { notice_text("providers.ai_intro") }
        dl do
          %i[typesafe openai].each do |provider|
            dt { strong { notice_text("providers.#{provider}.name") } }
            dd { p { notice_text("providers.#{provider}.description") } }
          end
        end
      end
    end
  end
end

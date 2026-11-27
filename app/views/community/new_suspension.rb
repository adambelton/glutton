module Views
  module Community
    class NewSuspension < ::Views::Base
      def initialize(member:, report_id:)
        @member, @report_id = member, report_id
      end

      def view_template
        page(title: t("community.suspensions.action"), narrow: true) do
          p { t("community.suspensions.confirm", name: member_name) }
          form_with(url: community_suspensions_path, method: :post) do
            input(type: :hidden, name: "suspension[member_id]", value: @member.id)
            input(type: :hidden, name: "suspension[report_id]", value: @report_id) if @report_id.present?
            render Shared::ActionRow.new(full_width: true) do
              render RubyUI::Link.new(href: return_path, variant: :ghost, class: "ui-action-button") { t("community.curations.cancel") }
              render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button") { t("community.suspensions.action") }
            end
          end
        end
      end

      private

      def member_name
        @member.community_user&.community_username.presence || t("community.reports.resolution.moderator_account", id: @member.id)
      end

      def return_path
        return community_moderation_report_path(@report_id) if @report_id.present?

        profile = @member.community_user
        profile&.public_identity? ? community_member_path(profile) : community_suspensions_path
      end
    end
  end
end

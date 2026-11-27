module Views
  module Community
    class PublicProfile < ::Views::Base
      def initialize(community_user:, can_suspend:, can_block:)
        @community_user = community_user
        @can_suspend = can_suspend
        @can_block = can_block
      end

      def view_template
        page(title: name, narrow: true, heading_content: method(:identity_heading),
          back_to: community_path, back_label: t("community.curations.back")) do
          div(class: "community-comment-actions") do
            if @community_user.reportable_attributes.present?
              a(href: new_community_member_report_path(@community_user)) { t("community.reports.action") }
            end
            block_confirmation if @can_block
            if @can_suspend
              a(href: new_community_suspension_path(member_id: @community_user.user_id), class: "community-moderation-link") do
                t("community.suspensions.profile_action")
              end
            end
          end
        end
      end

      private

      def block_confirmation
        render Shared::ConfirmationDialog.new(id: "block-community-member", action_label: t("community.member_blocks.block"),
          title: t("community.member_blocks.confirm_title", name:), description: t("community.member_blocks.confirm_description"),
          cancel_label: t("community.curations.cancel"), url: community_member_block_path(@community_user),
          trigger_variant: :plain, method: :post)
      end

      def identity_heading
        span(class: "flex items-center gap-3") do
          render ::Community::MemberAvatar.new(community_user: @community_user)
          plain name
        end
      end

      def name
        @community_user.community_username.presence || t("community.curations.member")
      end
    end
  end
end

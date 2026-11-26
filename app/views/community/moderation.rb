module Views
  module Community
    class Moderation < ::Views::Base
      def view_template
        page(title: t("community.moderation.title"), heading_outside_card: true,
          back_to: community_path, back_label: t("community.moderation.back")) do
          p(class: "ui-empty") { t("community.moderation.tools_pending") }
        end
      end
    end
  end
end

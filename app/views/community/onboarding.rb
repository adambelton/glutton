module Views
  module Community
    class Onboarding < ::Views::Base
      def view_template
        page(title: t("community.title")) do
          render ::Community::ConductAcceptanceForm.new(user: current_user, source: "community")
        end
      end
    end
  end
end

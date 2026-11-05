module Views
  module Identity
    class DeliveryLimit < ::Views::Base
      def view_template
        page(title: t("identity.registration.delivery_limit_title"), narrow: true) do
          p(role: "alert") { t("identity.registration.delivery_limit") }
          text_link(t("identity.registration.restart"), new_registration_path)
        end
      end
    end
  end
end

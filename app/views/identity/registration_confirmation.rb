module Views
  module Identity
    class RegistrationConfirmation < ::Views::Base
      def initialize(token:)
        @token = token
      end

      def view_template
        page(title: t("identity.registration.confirm_title"), narrow: true, pending_reminder: false) do
          p { t("identity.registration.confirm_explanation") }
          form_with(url: registration_confirmation_path) do
            input(type: "hidden", name: "token", value: @token)
            submit(t("identity.registration.confirm"))
          end
        end
      end
    end
  end
end

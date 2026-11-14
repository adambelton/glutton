module Views
  module Identity
    class ConfirmAccountEmail < ::Views::Base
      def initialize(token:, address:)
        @token = token
        @address = address
      end

      def view_template
        page(title: t("identity.settings.confirm_email"), narrow: true) do
          p { t("identity.settings.confirm_address", email: @address) }
          form_with(url: confirm_account_email_path) do
            input(type: "hidden", name: "token", value: @token)
            submit(t("identity.settings.confirm_email"))
          end
        end
      end
    end
  end
end

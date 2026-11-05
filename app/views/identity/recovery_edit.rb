module Views
  module Identity
    class RecoveryEdit < ::Views::Base
      def initialize(reset_user:, token:)
        @reset_user, @token = reset_user, token
      end

      def view_template
        page(title: t("identity.recovery.reset_title"), narrow: true) do
          errors(@reset_user.errors.full_messages)
          form_with(url: password_reset_path, method: :patch) do
            input(type: "hidden", name: "token", value: @token)
            field(name: "password", id: "password", label: t("identity.recovery.new_password"), type: :password, required: true, autocomplete: "new-password")
            field(name: "password_confirmation", id: "password_confirmation", label: t("identity.registration.password_confirmation"), type: :password, required: true, autocomplete: "new-password")
            submit(t("identity.recovery.reset_submit"))
          end
        end
      end
    end
  end
end

module Views
  module Identity
    class RegistrationConflict < ::Views::Base
      def initialize(warning: nil)
        @warning = warning
      end

      def view_template
        page(title: t("identity.registration.conflict_title"), narrow: true) do
          p(role: "alert") { t("identity.registration.conflict") }
          p { @warning } if @warning.present?
          render Shared::ActionButton.new(text: t("identity.sessions.sign_out"), url: session_path, method: :delete)
        end
      end
    end
  end
end

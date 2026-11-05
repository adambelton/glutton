module Identity
  class AccountStatus < UI::Base
    def initialize(user:)
      @user = user
    end

    def view_template
      if @user
        if @user.can_register?
          p { t("identity.sessions.guest_status") }
          p { t("identity.registration.guest_temporary") }
          text_link(t("identity.sessions.sign_in"), new_session_path)
          text_link(t("identity.registration.title"), new_registration_path)
        else
          p { t("identity.sessions.registered_status") }
        end
        render UI::ActionButton.new(text: t("identity.sessions.sign_out"), url: session_path, method: :delete)
      else
        text_link(t("identity.sessions.sign_in"), new_session_path)
        text_link(t("identity.registration.title"), new_registration_path)
      end
    end
  end
end

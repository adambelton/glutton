module Identity
  class PendingDetails < UI::Base
    def initialize(registration:)
      @registration = registration
    end

    def view_template
      p { t("identity.registration.verify_required") }
      p { t("identity.registration.expires", deadline: I18n.l(@registration.expires_at, format: :registration)) }
      p { t("identity.registration.guest_temporary") } if @registration.guest_user_id.present?
    end
  end
end

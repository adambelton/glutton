module Identity
  module RegistrationRequests
    extend ActiveSupport::Concern

    # Per worker, as with sign-in. A shared store is required before multi-worker release.
    RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

    included do
      before_action :registration_headers
      rescue_from Identity::RegistrationUnavailable do
        render "registrations/unavailable", status: :unprocessable_entity
      end
      rescue_from Identity::RegistrationConflict do
        render "registrations/conflict", status: :conflict
      end
      rescue_from Identity::DeliverRegistrationConfirmation::Limited do
        render plain: I18n.t("identity.registration.limited"), status: :too_many_requests
      end
      rescue_from Identity::DeliverRegistrationConfirmation::Exhausted do
        render "registrations/delivery_limit", status: :too_many_requests
      end
      rescue_from Identity::DeliverRegistrationConfirmation::Failed do
        redirect_to registration_path, alert: I18n.t("identity.registration.delivery_failed"), status: :see_other
      end
    end

    private

    def registration_headers
      response.headers["Cache-Control"] = "no-store"
      response.headers["Referrer-Policy"] = "no-referrer"
    end

    def registration_limited
      render plain: I18n.t("identity.registration.limited"), status: :too_many_requests
    end

    def reject_registered_registration
      raise Identity::RegistrationConflict if current_user.is_a?(RegisteredUser)
    end
  end
end

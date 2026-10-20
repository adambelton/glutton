module Identity
  module UserSessions
    extend ActiveSupport::Concern

    included do
      helper_method :current_user, :current_pending_registration
      before_action :prevent_identity_caching

      rescue_from Identity::AccountDeleted do
        session.delete(:pending_registration_id)
        render "sessions/deleted", status: :gone
      end
    end

    private

    def current_user
      return @current_user if defined?(@current_user)

      payload = identity_payload
      user = User.find_by(id: payload["user_id"]) if payload
      @current_user = user&.resume_session(session: bound_session)
      clear_identity_cookie unless @current_user
      @current_user
    end

    def ensure_guest_user!
      user = current_user
      if user.present?
        pending = current_pending_registration
        if user.can_register? && pending.present? && pending.guest_user_id.nil?
          Identity::AttachRegistration.call(pending_registration_id: pending.id, guest_user_id: user.id)
        end
        return user
      end

      pending = current_pending_registration
      authentication = Session.transaction do
        guest = UserGuest.create!
        if pending.present?
          Identity::AttachRegistration.call(pending_registration_id: pending.id, guest_user_id: guest.id)
        end
        Session.create!(user: guest)
      end
      bind_session(authentication)
      @current_user
    rescue Identity::RegistrationUnavailable
      # A link may expire or be consumed while guest creation waits for locks.
      pending = PendingRegistration.find_by(id: session[:pending_registration_id])
      raise if pending.present? && pending.active?

      session.delete(:pending_registration_id)
      flash.now[:alert] = I18n.t("identity.registration.unavailable")
      remove_instance_variable(:@current_user) if defined?(@current_user)
      retry
    end

    def current_pending_registration
      id = session[:pending_registration_id]
      return if id.nil?

      registration = PendingRegistration.find_by(id: id)
      user = current_user
      if registration&.available_to?(user:)
        registration
      else
        session.delete(:pending_registration_id)
        flash.now[:alert] = I18n.t("identity.registration.unavailable")
        nil
      end
    end

    def identity_payload
      payload = cookies.signed[:session_id]
      if payload.is_a?(Hash) && payload.values_at("id", "user_id").all? { |id| id.is_a?(Integer) && id.positive? }
        payload
      end
    end

    def bound_session
      return @bound_session if defined?(@bound_session)

      payload = identity_payload
      @bound_session = Session.find_by(id: payload["id"], user_id: payload["user_id"]) if payload
    end

    def bind_session(authentication)
      user = authentication.user
      if user.can_register? && session[:pending_registration_id].present?
        pending = PendingRegistration.find_by(id: session[:pending_registration_id])
      end
      registration_alert = flash[:alert]
      reset_session
      flash.now[:alert] = registration_alert if user.can_register? && registration_alert.present?
      if user.can_register? && pending.present? && pending.active? && pending.guest_user_id == user.id
        session[:pending_registration_id] = pending.id
      end
      cookies.signed[:session_id] = {
        value: { id: authentication.id, user_id: user.id },
        httponly: true, same_site: :lax, secure: Rails.env.production?, expires: user.remember_session_until
      }
      @bound_session = authentication
      @current_user = user
    end

    def clear_identity_cookie
      cookies.delete(:session_id)
      @bound_session = nil
      @current_user = nil
    end

    def prevent_identity_caching
      response.headers["Cache-Control"] = "no-store"
    end
  end
end

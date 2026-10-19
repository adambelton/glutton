module Identity
  module UserSessions
    extend ActiveSupport::Concern

    class AccountDeleted < StandardError; end

    included do
      helper_method :current_user
      before_action :prevent_identity_caching

      rescue_from AccountDeleted do
        render "sessions/deleted", status: :gone
      end
    end

    private

    def current_user
      return @current_user if defined?(@current_user)

      payload = identity_payload
      user = User.find_by(id: payload["user_id"]) if payload
      raise AccountDeleted if user.is_a?(DeletedUser)

      @current_user = bound_session&.active? ? user : nil
      clear_identity_cookie unless @current_user
      @current_user
    end

    def ensure_guest_user!
      user = current_user
      return user if user

      authentication = Session.transaction do
        Session.create!(user: GuestUser.create!)
      end
      bind_session(authentication)
      @current_user
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
      reset_session
      user = authentication.user
      jar = user.is_a?(RegisteredUser) ? cookies.signed.permanent : cookies.signed
      jar[:session_id] = {
        value: { id: authentication.id, user_id: user.id },
        httponly: true, same_site: :lax, secure: Rails.env.production?
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

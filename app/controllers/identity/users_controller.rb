module Identity
  class UsersController < ApplicationController
    before_action :require_superuser

    rescue_from Errors::SuperuserRequired do
      head :forbidden
    end

    rescue_from Errors::Unavailable do
      head :not_found
    end

    def index
      page = params.fetch(:page, "1")
      return head :bad_request unless page.is_a?(String) && page.match?(/\A[1-9]\d{0,5}\z/)

      input = request.post? ? params.fetch(:account_email_or_id, "") : ""
      return head :bad_request unless input.is_a?(String) && input.bytesize <= 254

      query = input.strip
      users = AccountAdministration::InspectUsers.page(number: page.to_i, query:)
      render ::Views::Admin::Users::Index.new(page: users, query:)
    end

    def show
      user_id = record_id(params[:id]) || raise(Errors::Unavailable)
      detail = AccountAdministration::InspectUsers.detail(user_id:)
      render ::Views::Admin::Users::Show.new(**detail)
    end

    def revoke_session
      user_id = record_id(params[:id]) || raise(Errors::Unavailable)
      session_id = record_id(params[:session_id])
      return head :bad_request unless session_id.present?

      actor_session_id = identity_payload.fetch("id")
      AccountAdministration::RevokeUserSession.call(user_id:, session_id:, actor_user_id: current_user.id, actor_session_id:)

      destination = admin_user_path(user_id)
      if actor_session_id == session_id
        clear_identity_cookie
        destination = new_session_path
      end
      redirect_to destination, status: :see_other, notice: t("identity.user_administration.revoked")
    rescue Errors::SessionUnavailable
      redirect_to admin_user_path(user_id), status: :see_other, alert: t("identity.user_administration.session_unavailable")
    end

    private

    def require_superuser
      head :forbidden unless current_user.superuser?
    end

    def record_id(value)
      value.to_i if value.is_a?(String) && value.match?(/\A[1-9]\d{0,17}\z/)
    end
  end
end

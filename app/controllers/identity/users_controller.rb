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
      query = request.post? ? params.fetch(:account_email_or_id, "") : ""
      search = CollectionSearchParameters.parse(query:, page: params.fetch(:page, "1"), max_digits: 6)
      return head :bad_request unless search.present?

      users = AccountAdministration::BrowseUsers.page(number: search.page, query: search.query)
      render ::Views::Admin::Users::Index.new(page: users, query: search.query)
    end

    def show
      user_id = record_id(params[:id]) || raise(Errors::Unavailable)
      detail = AccountAdministration::BrowseUsers.detail(user_id:)
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

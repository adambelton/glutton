class RegistrationConfirmationsController < ApplicationController
  include Identity::RegistrationRequests

  rate_limit to: 10, within: 3.minutes, scope: :registration_confirmation,
    store: Identity::RegistrationRequests::RATE_LIMIT_STORE, only: :create, with: :registration_limited

  def show
    user = current_user
    @token = params[:token]
    registration = PendingRegistration.resolve_confirmation!(token: @token)
    registration.authorize_confirmation!(user:, pending_registration_id: session[:pending_registration_id]) if user
  end

  def create
    new_session = Identity::CompleteBrowserRegistration.call(token: params[:token], current_user_id: current_user&.id,
      pending_registration_id: session[:pending_registration_id])
    bind_session(new_session)
    redirect_to root_path, notice: I18n.t("identity.registration.completed"), status: :see_other
  end
end

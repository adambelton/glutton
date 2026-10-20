class RegistrationConfirmationsController < ApplicationController
  include Identity::RegistrationRequests

  rate_limit to: 10, within: 3.minutes, scope: :registration_confirmation,
    store: Identity::RegistrationRequests::RATE_LIMIT_STORE, only: :create, with: :registration_limited

  def show
    user = current_user
    raise Identity::RegistrationConflict if user && !user.can_register?

    @token = params[:token]
    raise Identity::RegistrationUnavailable unless @token.is_a?(String) && @token.present?

    registration = PendingRegistration.find_by_token_for(:email_confirmation, @token)
    raise Identity::RegistrationUnavailable unless registration.present? && registration.active?

    if user.present? && registration.guest_user_id != user.id &&
        !(registration.guest_user_id.nil? && registration.id == session[:pending_registration_id])
      raise Identity::RegistrationConflict
    end
  end

  def create
    new_session = Identity::CompleteBrowserRegistration.call(token: params[:token], current_user_id: current_user&.id,
      pending_registration_id: session[:pending_registration_id])
    bind_session(new_session)
    redirect_to root_path, notice: I18n.t("identity.registration.completed"), status: :see_other
  end
end

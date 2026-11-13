require "digest"


class PasswordResetsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create, :edit, :update ]

  # Per worker, as with sign-in. Shared abuse controls are required before multi-worker release.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  before_action :recovery_headers
  rate_limit to: 10, within: 3.minutes, store: RATE_LIMIT_STORE, name: :request_ip, only: :create, with: :limited
  rate_limit to: 1, within: 1.minute, store: RATE_LIMIT_STORE, name: :request_email,
    by: :email_fingerprint, only: :create, with: :limited
  rate_limit to: 10, within: 3.minutes, store: RATE_LIMIT_STORE, name: :update_ip, only: :update, with: :limited
  before_action :load_reset_user, only: [ :edit, :update ]

  rescue_from Identity::Errors::PasswordResetUnavailable do
    render ::Views::Identity::RecoveryUnavailable.new, status: :unprocessable_entity
  end
  rescue_from Identity::Errors::PasswordResetConflict do
    render ::Views::Identity::RecoveryConflict.new, status: :conflict
  end
  rescue_from Identity::Errors::PasswordResetDeliveryFailed do
    @delivery_error = I18n.t("identity.recovery.delivery_failed")
    render ::Views::Identity::RecoveryNew.new(delivery_error: @delivery_error), status: :service_unavailable
  end

  def new
    render ::Views::Identity::RecoveryNew.new
  end

  def create
    Identity::PasswordRecovery::RequestPasswordReset.call(email_address: params.permit(:email_address)[:email_address])
    flash[:page_notice] = I18n.t("identity.recovery.requested")
    redirect_to new_session_path, status: :see_other
  end

  def edit
    render ::Views::Identity::RecoveryEdit.new(reset_user: @reset_user, token: @token)
  end

  def update
    credentials = { password: nil, password_confirmation: nil }.merge(params.permit(:password, :password_confirmation).to_h.symbolize_keys)
    user = Identity::PasswordRecovery::ResetPassword.call(token: @token, **credentials)
    if current_user&.id == user.id
      clear_identity_cookie
      reset_session
    end
    flash[:page_notice] = I18n.t("identity.recovery.completed")
    redirect_to new_session_path, status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @reset_user = error.record
    render ::Views::Identity::RecoveryEdit.new(reset_user: @reset_user, token: @token), status: :unprocessable_entity
  end

  private

  def recovery_headers
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    current_user
  end

  def email_fingerprint
    email = params.permit(:email_address)[:email_address]
    Digest::SHA256.hexdigest(email.is_a?(String) ? email.strip.downcase : "")
  end

  def limited
    render plain: I18n.t("identity.recovery.limited"), status: :too_many_requests
  end

  def load_reset_user
    @token = params[:token]
    @reset_user = Identity::PasswordRecovery::ResolvePasswordReset.call(token: @token, current_user_id: current_user&.id)
  end
end

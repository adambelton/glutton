require "digest"

class PasswordResetsController < ApplicationController
  # Per worker, as with sign-in. Shared abuse controls are required before multi-worker release.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  before_action :recovery_headers
  rate_limit to: 10, within: 3.minutes, store: RATE_LIMIT_STORE, name: :request_ip, only: :create, with: :limited
  rate_limit to: 1, within: 1.minute, store: RATE_LIMIT_STORE, name: :request_email,
    by: :email_fingerprint, only: :create, with: :limited
  rate_limit to: 10, within: 3.minutes, store: RATE_LIMIT_STORE, name: :update_ip, only: :update, with: :limited
  before_action :load_reset_user, only: [ :edit, :update ]

  rescue_from Identity::PasswordResetUnavailable do
    render :unavailable, status: :unprocessable_entity
  end
  rescue_from Identity::RequestPasswordReset::Failed do
    @delivery_error = I18n.t("identity.recovery.delivery_failed")
    render :new, status: :service_unavailable
  end

  def new
  end

  def create
    Identity::RequestPasswordReset.call(email_address: params.permit(:email_address)[:email_address])
    redirect_to new_session_path, notice: I18n.t("identity.recovery.requested"), status: :see_other
  end

  def edit
  end

  def update
    credentials = { password: nil, password_confirmation: nil }.merge(params.permit(:password, :password_confirmation).to_h.symbolize_keys)
    user = Identity::ResetPassword.call(token: @token, **credentials)
    if current_user.is_a?(RegisteredUser) && current_user.id == user.id
      clear_identity_cookie
      reset_session
    end
    redirect_to new_session_path, notice: I18n.t("identity.recovery.completed"), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @reset_user = error.record
    render :edit, status: :unprocessable_entity
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
    raise Identity::PasswordResetUnavailable unless @token.is_a?(String) && @token.present?

    @reset_user = RegisteredUser.find_by_password_reset_token(@token)
    unless @reset_user.present? && @reset_user.active? && @reset_user.email_confirmed_at.present?
      raise Identity::PasswordResetUnavailable
    end
    if current_user.is_a?(RegisteredUser) && current_user.id != @reset_user.id
      render :conflict, status: :conflict
    end
  end
end

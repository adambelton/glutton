class AccountSettingsController < ApplicationController
  before_action :require_account_access
  before_action :require_community_preview_access, only: [ :show_community, :change_community_username ]

  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 5, within: 3.minutes, by: -> { current_user.id }, store: RATE_LIMIT_STORE,
    only: [ :request_email, :change_password ],
    with: -> { redirect_to account_settings_path, alert: t("identity.settings.rate_limited"), status: :see_other }

  rescue_from Identity::Errors::Unavailable do
    head :forbidden
  end

  rescue_from Identity::Errors::DeletionLogUnavailable do
    redirect_to account_settings_path, alert: t("identity.settings.deletion_log_unavailable"), status: :see_other
  end

  rescue_from Identity::Errors::AccountChangeUnavailable do
    redirect_to account_settings_path, alert: t("identity.settings.email_unavailable"), status: :see_other
  end

  rescue_from Identity::Errors::EmailChangeDeliveryFailed do
    redirect_to account_settings_path, alert: t("identity.settings.email_delivery_failed"), status: :see_other
  end

  rescue_from Identity::Errors::IncorrectCurrentPassword do
    render_credential_errors([ t("identity.settings.incorrect_current_password") ])
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_credential_errors(error.record.errors.full_messages)
  end

  def show
    render_settings
  end

  def show_community
    render_community_settings(editing_username: params[:edit] == "username")
  end

  def request_email
    credentials = params.permit(:current_password, :email_address)
    settings.request_email_change(current_password: credentials[:current_password], email_address: credentials[:email_address])
    redirect_to account_settings_path, notice: t("identity.settings.email_sent"), status: :see_other
  end

  def show_email_confirmation
    token = params.permit(:token)[:token]
    address = settings.email_change_address(token:)
    render Views::Identity::ConfirmAccountEmail.new(token:, address:)
  end

  def confirm_email
    settings.confirm_email_change(token: params.permit(:token)[:token])
    finish_session(new_session_path, t("identity.settings.email_changed"))
  end

  def change_password
    credentials = params.permit(:current_password, :password, :password_confirmation)
    settings.change_password(current_password: credentials[:current_password], password: credentials[:password],
      password_confirmation: credentials[:password_confirmation])
    finish_session(new_session_path, t("identity.settings.password_changed"))
  end

  def change_community_username
    community_username = params[:community_username]
    settings.change_community_username(community_username: community_username.is_a?(String) ? community_username : nil)
    redirect_to account_community_path, notice: t("identity.settings.community_username.saved"), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    raise if error.record.errors[:community_username].empty?

    render_community_settings(editing_username: true, form_username: error.record.community_username,
      username_errors: error.record.errors.full_messages_for(:community_username), status: :unprocessable_entity)
  end

  def destroy
    settings.close_account
    finish_session(root_path, t("identity.settings.deleted"))
  end

  private

  def settings
    Identity::AccountAdministration::ManageRegisteredAccount.new(user_id: current_user.id)
  end

  def require_account_access
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    head :forbidden unless current_user.can_view_account?
  end

  def require_community_preview_access
    head :forbidden unless Community::PreviewAccess.allowed?(user: current_user)
  end

  def render_credential_errors(errors)
    dialog = { "request_email" => :email, "change_password" => :password }[action_name]
    render_settings(errors:, open_dialog: dialog, status: :unprocessable_entity)
  end

  def render_settings(errors: [], open_dialog: nil, status: :ok)
    render Views::Identity::AccountSettings.new(email_address: current_user.email_address, validation_errors: errors, open_dialog:), status:
  end

  def render_community_settings(editing_username:, form_username: current_user.community_username, username_errors: [], status: :ok)
    render Views::Identity::AccountCommunity.new(community_username: current_user.community_username,
      editing_username:, form_username:, username_errors:), status:
  end

  def finish_session(destination, message)
    clear_identity_cookie
    reset_session
    redirect_to destination, notice: message, status: :see_other
  end
end

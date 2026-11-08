class SessionsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create, :destroy ]

  # Per worker; resets on restart. Use a shared store before multi-worker release.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  rate_limit to: 10, within: 3.minutes, store: RATE_LIMIT_STORE, only: :create,
    with: -> { render plain: I18n.t("identity.sessions.rate_limited"), status: :too_many_requests }

  rescue_from Identity::AccountDeleted do
    render ::Views::Identity::SignIn.new(error: @error, account_controls: false),
      status: @error.present? ? :unprocessable_entity : :ok
  end

  def new
    render ::Views::Identity::SignIn.new
  end

  def create
    new_session = Identity::Session.transaction do
      created_session = Identity::Authenticate.call(email_address: params[:email_address], password: params[:password])
      Identity::Session.revoke(id: bound_session.id) if created_session.present? && bound_session.present?
      created_session
    end

    if new_session.present?
      bind_session(new_session)
      redirect_to entry_destination, status: :see_other
    else
      @error = I18n.t("identity.sessions.invalid_credentials")
      render ::Views::Identity::SignIn.new(error: @error), status: :unprocessable_entity
    end
  end

  def destroy
    Identity::Session.revoke(id: bound_session.id) if bound_session.present?
    clear_identity_cookie
    reset_session
    redirect_to root_path, notice: I18n.t("identity.sessions.signed_out"), status: :see_other
  end
end

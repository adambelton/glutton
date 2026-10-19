class SessionsController < ApplicationController
  # Per worker; resets on restart. Use a shared store before multi-worker release.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  rate_limit to: 10, within: 3.minutes, store: RATE_LIMIT_STORE, only: :create,
    with: -> { render plain: I18n.t("identity.sessions.rate_limited"), status: :too_many_requests }

  def new
  end

  def create
    new_session = Session.transaction do
      created_session = Identity::Authenticate.call(email_address: params[:email_address], password: params[:password])
      Session.revoke(id: bound_session.id) if created_session && bound_session
      created_session
    end

    if new_session
      bind_session(new_session)
      redirect_to root_path, notice: I18n.t("identity.sessions.signed_in"), status: :see_other
    else
      @error = I18n.t("identity.sessions.invalid_credentials")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    Session.revoke(id: bound_session.id) if bound_session
    clear_identity_cookie
    reset_session
    redirect_to root_path, notice: I18n.t("identity.sessions.signed_out"), status: :see_other
  end
end

class GuestSessionsController < ApplicationController
  allow_unauthenticated_access only: :create

  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 10, within: 3.minutes, store: RATE_LIMIT_STORE, only: :create,
    with: -> { render plain: I18n.t("identity.sessions.rate_limited"), status: :too_many_requests }

  def create
    ensure_guest_user!
    redirect_to entry_destination, status: :see_other
  end

  def destroy
    Identity::AccountAdministration::DiscardGuestAccount.call(user_id: current_user.id)
    clear_identity_cookie
    reset_session
    redirect_to root_path, notice: I18n.t("identity.entry.guest_discarded"), status: :see_other
  rescue Identity::Errors::Unavailable
    head :forbidden
  end
end

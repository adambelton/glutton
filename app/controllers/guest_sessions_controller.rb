class GuestSessionsController < ApplicationController
  allow_unauthenticated_access only: :create

  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 10, within: 3.minutes, store: RATE_LIMIT_STORE,
    with: -> { render plain: I18n.t("identity.sessions.rate_limited"), status: :too_many_requests }

  def create
    ensure_guest_user!
    redirect_to entry_destination, status: :see_other
  end
end

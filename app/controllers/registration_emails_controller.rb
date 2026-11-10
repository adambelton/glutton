class RegistrationEmailsController < ApplicationController
  allow_unauthenticated_access only: :create

  include Identity::RegistrationRequests

  rate_limit to: 10, within: 3.minutes, scope: :registration_email,
    store: Identity::RegistrationRequests::RATE_LIMIT_STORE, only: :create, with: :registration_limited

  def create
    registration = current_pending_registration
    raise Identity::Errors::RegistrationUnavailable if registration.nil?

    Identity::Registration::DeliverRegistrationConfirmation.call(pending_registration_id: registration.id)
    redirect_to registration_path, notice: I18n.t("identity.registration.accepted"), status: :see_other
  end
end

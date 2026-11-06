class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create, :show ]

  include Identity::RegistrationRequests

  rate_limit to: 10, within: 3.minutes, scope: :registration_email,
    store: Identity::RegistrationRequests::RATE_LIMIT_STORE, only: :create, with: :registration_limited
  before_action :reject_registered_registration

  def new
    @registration = Identity::PendingRegistration.new
    render ::Views::Identity::RegistrationNew.new(registration: @registration)
  end

  def create
    previous = current_pending_registration
    credentials = { email_address: nil, password: nil, password_confirmation: nil }.merge(
      params.expect(registration: [ :email_address, :password, :password_confirmation ]).to_h.symbolize_keys)
    @registration = Identity::SubmitRegistration.call(previous_id: previous&.id, guest_user_id: current_user&.id, **credentials)
    session[:pending_registration_id] = @registration.id
    Identity::DeliverRegistrationConfirmation.call(pending_registration_id: @registration.id)
    redirect_to registration_path, notice: I18n.t("identity.registration.accepted"), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @registration = error.record
    render ::Views::Identity::RegistrationNew.new(registration: @registration), status: :unprocessable_entity
  end

  def show
    @registration = current_pending_registration
    raise Identity::RegistrationUnavailable if @registration.nil?

    render ::Views::Identity::RegistrationPending.new(registration: @registration)
  end
end

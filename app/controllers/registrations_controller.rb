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
    submitted = params.expect(registration: [ :email_address, :password, :password_confirmation, :terms_accepted, :terms_version, :privacy_notice_version ])
    terms_version = Identity::TermsOfService.current.version
    privacy_notice_version = Identity::PrivacyNotice.current.version
    if submitted[:terms_version] != terms_version || submitted[:privacy_notice_version] != privacy_notice_version
      @registration = Identity::PendingRegistration.new(email_address: submitted[:email_address])
      @registration.errors.add(:base, I18n.t("identity.registration.policies_updated"))
      return render ::Views::Identity::RegistrationNew.new(registration: @registration), status: :unprocessable_entity
    end

    unless submitted[:terms_accepted] == "1"
      @registration = Identity::PendingRegistration.new(email_address: submitted[:email_address])
      @registration.errors.add(:terms_accepted, :accepted)
      return render ::Views::Identity::RegistrationNew.new(registration: @registration), status: :unprocessable_entity
    end
    credentials = { email_address: nil, password: nil, password_confirmation: nil }.merge(
      submitted.except(:terms_accepted, :terms_version, :privacy_notice_version).to_h.symbolize_keys)
    Identity::Registration::StartBrowserRegistration.call(
      previous_id: previous&.id, guest_user_id: current_user&.id, terms_version:,
      terms_accepted_at: Time.current, privacy_notice_version:, **credentials
    ) do |pending_registration_id|
      session[:pending_registration_id] = pending_registration_id
    end
    flash[:page_notice] = I18n.t("identity.registration.accepted")
    redirect_to registration_path, status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @registration = error.record
    render ::Views::Identity::RegistrationNew.new(registration: @registration), status: :unprocessable_entity
  end

  def show
    @registration = current_pending_registration
    raise Identity::Errors::RegistrationUnavailable if @registration.nil?

    render ::Views::Identity::RegistrationPending.new(registration: @registration)
  end
end

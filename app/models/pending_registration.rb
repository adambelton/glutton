require "digest"

class PendingRegistration < ApplicationRecord
  belongs_to :guest_user, class_name: "GuestUser", optional: true

  generates_token_for :email_confirmation, expires_in: 1.hour do
    Digest::SHA256.hexdigest([ email_address, password_digest ].to_json)
  end

  has_secure_password reset_token: false
  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password_digest, presence: true
  validates :password, presence: true, on: :create
  validates :password, length: { minimum: 15 }, allow_nil: true
  validates :password_confirmation, presence: true, if: -> { password.present? }

  def active?
    return false unless persisted? && created_at + 24.hours > Time.current

    guest_user_id.nil? || GuestUser.active.exists?(guest_user_id)
  end
end

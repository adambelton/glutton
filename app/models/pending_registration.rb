class PendingRegistration < ApplicationRecord
  belongs_to :guest_user, class_name: "GuestUser", optional: true

  has_secure_password reset_token: false
  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password_digest, presence: true
  validates :password, presence: true, on: :create
  validates :password, length: { minimum: 15 }, allow_nil: true
  validates :password_confirmation, presence: true, if: -> { password.present? }
end

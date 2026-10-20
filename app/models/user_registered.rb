class UserRegistered < User
  has_secure_password reset_token: { expires_in: 15.minutes }

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :password_digest, :email_confirmed_at, presence: true
  validates :password, presence: true, on: [ :create, :password_reset ]
  validates :password, length: { minimum: 15 }, allow_nil: true
  validates :password_confirmation, presence: true, if: -> { password.present? }

  def self.find_by_email(email)
    return unless email.is_a?(String)

    canonical_email = normalize_value_for(:email_address, email)
    return unless URI::MailTo::EMAIL_REGEXP.match?(canonical_email)

    find_by(email_address: canonical_email)
  end
end

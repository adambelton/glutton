class UserRegistered < User
  has_secure_password reset_token: { expires_in: 15.minutes }

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :password_digest, :email_confirmed_at, presence: true
  validates :password, presence: true, on: [ :create, :password_reset ]
  validates :password, length: { minimum: 15 }, allow_nil: true
  validates :password_confirmation, presence: true, if: -> { password.present? }

  def can_reset_password?
    active? && email_confirmed_at.present?
  end

  def can_reset_password_for?(user:)
    active? && id == user.id
  end

  def reset_password!(password:, password_confirmation:)
    raise Identity::PasswordResetUnavailable unless can_reset_password?

    self.class.transaction do
      assign_attributes(password:, password_confirmation:)
      save!(context: :password_reset)
      Session.where(user_id: id).delete_all
      self
    end
  end

  def self.authenticate_credentials(email_address:, password:)
    return unless email_address.is_a?(String) && password.is_a?(String)
    return if email_address.blank? || password.blank?

    email = normalize_value_for(:email_address, email_address)
    return unless URI::MailTo::EMAIL_REGEXP.match?(email)

    user = authenticate_by(email_address: email, password:)
    user if user&.active? && user.email_confirmed_at.present?
  end

  def remember_session_until
    20.years.from_now
  end

  def self.find_by_email(email)
    return unless email.is_a?(String)

    canonical_email = normalize_value_for(:email_address, email)
    return unless URI::MailTo::EMAIL_REGEXP.match?(canonical_email)

    find_by(email_address: canonical_email)
  end
end

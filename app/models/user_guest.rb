class UserGuest < User
  validates :email_address, :password_digest, :email_confirmed_at, inclusion: { in: [ nil ] }

  scope :active, -> { where(arel_table[:created_at].gt(24.hours.ago)) }

  def sign_out_warning
    I18n.t("identity.registration.guest_signout_warning")
  end

  def registration_expires_at
    created_at + 24.hours
  end

  def can_reset_password_for?(user:)
    active?
  end

  def can_register?
    persisted? && active?
  end

  def active?
    registration_expires_at > Time.current
  end
end

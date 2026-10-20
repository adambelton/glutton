class UserGuest < User
  EXPIRY_DURATION = 24.hours.freeze

  validates :email_address, :password_digest, :email_confirmed_at, inclusion: { in: [ nil ] }

  scope :active, -> { where(arel_table[:created_at].gt(EXPIRY_DURATION.ago)) }
  scope :expired, -> { where(arel_table[:created_at].lteq(EXPIRY_DURATION.ago)) }

  def sign_out_warning
    I18n.t("identity.registration.guest_signout_warning")
  end

  def can_register?
    persisted? && active?
  end

  def active?
    created_at + EXPIRY_DURATION > Time.current
  end
end

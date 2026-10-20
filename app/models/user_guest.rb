class UserGuest < User
  validates :email_address, :password_digest, :email_confirmed_at, inclusion: { in: [ nil ] }

  scope :active, -> { where(arel_table[:created_at].gt(24.hours.ago)) }
  scope :expired, -> { where(arel_table[:created_at].lteq(24.hours.ago)) }

  def sign_out_warning
    I18n.t("identity.registration.guest_signout_warning")
  end

  def can_reset_password_for?(user:)
    active?
  end

  def can_register?
    persisted? && active?
  end

  def active?
    created_at + 24.hours > Time.current
  end
end

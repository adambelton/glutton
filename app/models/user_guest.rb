class UserGuest < User
  validates :email_address, :password_digest, :email_confirmed_at, inclusion: { in: [ nil ] }

  scope :active, -> { where(arel_table[:created_at].gt(24.hours.ago)) }

  def active?
    created_at + 24.hours > Time.current
  end
end

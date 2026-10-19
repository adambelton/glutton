class GuestUser < User
  validates :email_address, :password_digest, :email_confirmed_at, inclusion: { in: [ nil ] }

  def active?
    created_at + 24.hours > Time.current
  end
end

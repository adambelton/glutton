class UserDeleted < User
  validates :email_address, :password_digest, :email_confirmed_at, inclusion: { in: [ nil ] }

  def check_access!
    raise Identity::AccountDeleted
  end

  def active?
    false
  end
end

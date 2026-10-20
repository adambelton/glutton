class UserDeleted < User
  validates :email_address, :password_digest, :email_confirmed_at, inclusion: { in: [ nil ] }

  def inactive_error
    Identity::AccountDeleted.new
  end

  def active?
    false
  end
end

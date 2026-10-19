class DeletedUser < User
  validates :email_address, :password_digest, :email_confirmed_at, inclusion: { in: [ nil ] }

  def active?
    false
  end
end

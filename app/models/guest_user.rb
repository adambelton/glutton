class GuestUser < User
  include Identity::WithoutCredentials

  def active?
    created_at + 24.hours > Time.current
  end
end

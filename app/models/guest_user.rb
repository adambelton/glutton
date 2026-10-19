class GuestUser < User
  def active?
    created_at + 24.hours > Time.current
  end
end

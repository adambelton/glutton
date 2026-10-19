class GuestUser < User
  def expired?
    created_at + 24.hours <= Time.current
  end
end

class DeletedUser < User
  include Identity::WithoutCredentials

  def active?
    false
  end
end

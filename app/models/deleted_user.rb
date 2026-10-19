class DeletedUser < User
  def active?
    false
  end
end

class User < ApplicationRecord
  def initialize(...)
    raise NotImplementedError, "Construct a User subtype" if self.class == User

    super
  end

  def resume_session(session:)
    self if session&.active? && session.user_id == id
  end

  def remember_session_until
    nil
  end

  def sign_out_warning
    nil
  end

  def can_reset_password?
    false
  end

  def reset_password!(password:, password_confirmation:)
    raise Identity::PasswordResetUnavailable
  end

  def can_register?
    false
  end

  def active?
    true
  end
end

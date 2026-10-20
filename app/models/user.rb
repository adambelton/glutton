class User < ApplicationRecord
  def initialize(...)
    raise NotImplementedError, "Construct a User subtype" if self.class == User

    super
  end

  def check_access!
    self
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

  def can_reset_password_for?(user:)
    false
  end

  def reset_password!(password:, password_confirmation:)
    raise Identity::PasswordResetUnavailable
  end

  def can_register?
    false
  end

  def registration_expires_at
    nil
  end

  def active?
    true
  end
end

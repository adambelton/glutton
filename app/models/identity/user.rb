module Identity
  class User < ApplicationRecord
    self.store_full_sti_class = false

    def initialize(...)
      raise NotImplementedError, "Construct a User subtype" if self.class == User

      super
    end

    def default_entry_path
      raise NotImplementedError
    end

    def inactive_error
      nil
    end

    def session_duration
      nil
    end

    def sign_out_warning
      nil
    end

    def grant_superuser!(actor:)
      raise Identity::Errors::SuperuserUnavailable
    end

    def revoke_superuser!(actor:)
      raise Identity::Errors::SuperuserUnavailable
    end

    def can_reset_password?
      false
    end

    def reset_password!(password:, password_confirmation:)
      raise Identity::Errors::PasswordResetUnavailable
    end

    def can_register?
      false
    end

    def can_view_account?
      false
    end

    def active?
      true
    end
  end
end

module Identity
  class UserDeleted < User
    validates :superuser, inclusion: { in: [ false ] }

    validates :email_address, :password_digest, :email_confirmed_at, inclusion: { in: [ nil ] }

    def inactive_error
      Identity::Errors::AccountDeleted.new
    end

    def active?
      false
    end
  end
end

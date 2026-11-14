module Identity
  class UserDeleted < User
    validates :superuser, inclusion: { in: [ false ] }

    validates :email_address, :password_digest, :email_confirmed_at, inclusion: { in: [ nil ] }

    def close_account!
      assign_attributes(email_address: nil, password_digest: nil, email_confirmed_at: nil, superuser: false)
      save!
    end

    def inactive_error
      Identity::Errors::AccountDeleted.new
    end

    def active?
      false
    end
  end
end

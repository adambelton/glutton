module Identity
  class Authenticate
    def self.call(email_address:, password:)
      UserRegistered.transaction do
        # Verify credentials under the same user lock used by password recovery.
        user = UserRegistered.lock.authenticate_credentials(email_address:, password:)
        Session.create!(user:) if user
      end
    end
  end
end

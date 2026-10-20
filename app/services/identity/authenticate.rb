module Identity
  class Authenticate
    def self.call(email_address:, password:)
      user = UserRegistered.authenticate_credentials(email_address:, password:)
      Session.create!(user:) if user
    end
  end
end

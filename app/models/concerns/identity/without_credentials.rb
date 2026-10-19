module Identity
  module WithoutCredentials
    extend ActiveSupport::Concern

    included do
      validates :email_address, :password_digest, :email_confirmed_at, inclusion: { in: [ nil ] }
    end
  end
end

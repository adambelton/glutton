module Identity
  class CompleteBrowserRegistration
    def self.call(token:, current_user_id: nil, pending_registration_id: nil)
      CompleteRegistration.call(token:, current_user_id:, pending_registration_id:)
    end
  end
end

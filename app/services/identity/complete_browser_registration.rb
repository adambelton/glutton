module Identity
  class CompleteBrowserRegistration
    def self.call(token:, current_user_id: nil)
      CompleteRegistration.call(token:, current_user_id:)
    end
  end
end

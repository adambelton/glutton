module Community
  class PreviewAccess
    def self.allowed?(user:)
      user.superuser?
    end

    def self.require!(user:)
      raise Errors::MembershipRequired unless allowed?(user:)
    end
  end
end

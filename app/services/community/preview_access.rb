module Community
  class PreviewAccess
    def self.allowed?(user:)
      user.superuser?
    end
  end
end

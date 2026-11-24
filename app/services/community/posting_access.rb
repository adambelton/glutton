module Community
  class PostingAccess
    def self.allowed?(user:)
      PreviewAccess.allowed?(user:) && user.can_view_account? &&
        CodeOfConduct.current.accepted_by?(member: user) &&
        user.community_username.present? && user.community_avatar_preset.present?
    end
  end
end

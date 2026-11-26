module Community
  class ModeratorRole < ApplicationRecord
    self.table_name = "community_moderator_roles"

    belongs_to :member, class_name: "Identity::UserRegistered"
    belongs_to :granted_by, class_name: "Identity::UserRegistered", optional: true
    belongs_to :revoked_by, class_name: "Identity::UserRegistered", optional: true

    scope :active, -> { where(revoked_at: nil) }

    validates :granted_by, presence: true, on: :create

    def self.grant!(member:, actor:)
      raise Errors::ModeratorRoleUnavailable if active.exists?(member:)

      create!(member:, granted_by: actor, granted_at: Time.current)
    end

    def revoke!(actor:)
      raise Errors::ModeratorRoleUnavailable if revoked_at.present?

      update!(revoked_at: Time.current, revoked_by: actor)
    end
  end
end

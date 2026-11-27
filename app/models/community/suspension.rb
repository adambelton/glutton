module Community
  class Suspension < ApplicationRecord
    self.table_name = "community_suspensions"

    belongs_to :member, class_name: "Identity::UserRegistered"
    belongs_to :suspended_by, class_name: "Identity::UserRegistered", optional: true
    belongs_to :lifted_by, class_name: "Identity::UserRegistered", optional: true

    scope :active, -> { where(lifted_at: nil) }
    scope :lifted, -> { where.not(lifted_at: nil) }

    def self.start!(member:, moderator:)
      raise Errors::ModerationAccessDenied unless Moderation::Access.review?(user: moderator)
      raise Errors::SuspensionUnavailable unless Membership::Access.allowed?(user: member) && !active.exists?(member:)

      create!(member:, suspended_by: moderator, suspended_at: Time.current)
    end

    def lift!(moderator:)
      raise Errors::ModerationAccessDenied unless Moderation::Access.review?(user: moderator)
      raise Errors::SuspensionUnavailable if lifted_at.present?

      update!(lifted_by: moderator, lifted_at: Time.current)
    end
  end
end

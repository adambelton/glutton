module Community
  class CommunityUser < ApplicationRecord
    self.primary_key = :user_id

    RESERVED_USERNAMES = %w[admin administrator moderator glutton support].freeze
    AVATAR_PRESETS = %w[
      bloody_reel cleaver cabin static_tv skull
      tentacle heart vhs moth eye
      candles raven gravestone haunted_house planchette
      key lantern antlered_skull tree werewolf
      abduction gas_mask spellbook spaceman_mask
    ].freeze

    belongs_to :user, class_name: "Identity::UserRegistered", inverse_of: :community_user

    validates :community_username, format: { with: /\A[A-Za-z0-9_]{3,24}\z/ }, allow_nil: true
    validates :community_avatar_preset, inclusion: { in: AVATAR_PRESETS }, allow_nil: true
    validate :username_is_not_reserved

    def self.provision_for!(user:)
      raise Errors::CodeOfConductRequired unless CodeOfConduct.current.accepted_by?(user:)

      find_or_create_by!(user:)
    end

    def profile_editable?
      CodeOfConduct.current.accepted_by?(user:)
    end

    def ready_to_post?
      user.can_view_account? && profile_editable? && community_username.present? && community_avatar_preset.present?
    end

    def change_community_username!(community_username:)
      require_current_conduct!
      update!(community_username: community_username || "")
    rescue ActiveRecord::RecordNotUnique => error
      constraint = error.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      raise unless constraint == "community_users_username_unique"

      errors.add(:community_username, :taken)
      raise ActiveRecord::RecordInvalid, self
    end

    def choose_community_avatar!(preset:)
      require_current_conduct!
      update!(community_avatar_preset: preset || "")
    end

    private

    def require_current_conduct!
      raise Errors::CodeOfConductRequired unless profile_editable?
    end

    def username_is_not_reserved
      errors.add(:community_username, :reserved) if RESERVED_USERNAMES.include?(community_username&.downcase)
    end
  end
end

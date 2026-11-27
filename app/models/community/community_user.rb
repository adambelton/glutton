module Community
  class CommunityUser < ApplicationRecord
    include Reportable
    include Blockable

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
    has_many :outgoing_blocks, class_name: "Community::MemberBlock", foreign_key: :blocker_id, inverse_of: :blocker

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
      Membership::Access.participation_allowed?(user:) && profile_editable? && community_username.present? && community_avatar_preset.present?
    end

    def reportable_attributes
      { "community_username" => community_username }.compact_blank
    end

    def public_identity?
      community_username.present? || community_avatar_preset.present?
    end

    def member_id_for_blocking
      id
    end

    def member_hidden?(member_id)
      return false if member_id.nil? || member_id == id

      (@hidden_member_ids ||= MemberBlock.hidden_ids_for(id)).include?(member_id)
    end

    def can_block_member?(member:)
      ready_to_post? && block_available?(member:)
    end

    def block_member!(member:)
      raise Errors::PostingUnavailable unless ready_to_post?
      raise Errors::MemberBlockUnavailable unless block_available?(member:)

      outgoing_blocks.create!(blocked: member)
    end

    def unblock_member!(member:)
      block = outgoing_blocks.find_by(blocked: member)
      raise Errors::MemberBlockUnavailable unless block.present?

      block.destroy!
    end

    def reported_member
      user
    end

    def change_community_username!(community_username:)
      Membership::Access.require_participation!(user:)
      require_current_conduct!
      update!(community_username: community_username || "")
    rescue ActiveRecord::RecordNotUnique => error
      constraint = error.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      raise unless constraint == "community_users_username_unique"

      errors.add(:community_username, :taken)
      raise ActiveRecord::RecordInvalid, self
    end

    def choose_community_avatar!(preset:)
      Membership::Access.require_participation!(user:)
      require_current_conduct!
      update!(community_avatar_preset: preset || "")
    end

    private

    def block_available?(member:)
      member.id != id && member.public_identity? && !outgoing_blocks.exists?(blocked: member)
    end

    def independently_deletable_attributes
      %w[community_username]
    end

    def require_current_conduct!
      raise Errors::CodeOfConductRequired unless profile_editable?
    end

    def username_is_not_reserved
      errors.add(:community_username, :reserved) if RESERVED_USERNAMES.include?(community_username&.downcase)
    end
  end
end

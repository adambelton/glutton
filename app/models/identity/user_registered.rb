require "digest"

module Identity
  class UserRegistered < User
    RESERVED_COMMUNITY_USERNAMES = %w[admin administrator moderator glutton support].freeze
    COMMUNITY_AVATAR_PRESETS = %w[
      bloody_reel cleaver cabin static_tv skull
      tentacle heart vhs moth eye
      candles raven gravestone haunted_house planchette
      key lantern antlered_skull tree werewolf
      abduction gas_mask spellbook spaceman_mask
    ].freeze

    has_secure_password reset_token: { expires_in: 15.minutes }

    normalizes :email_address, with: ->(email) { email.strip.downcase }

    validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
    validates :password_digest, :email_confirmed_at, presence: true
    validates :password, presence: true, on: [ :create, :password_reset ]
    validates :password, length: { minimum: 15 }, allow_nil: true
    validates :password_confirmation, presence: true, if: -> { password.present? }
    validates :community_username, format: { with: /\A[A-Za-z0-9_]{3,24}\z/ }, allow_nil: true
    validates :community_avatar_preset, inclusion: { in: COMMUNITY_AVATAR_PRESETS }, allow_nil: true
    validate :community_username_is_not_reserved

    def default_entry_path
      "/library"
    end

    def can_view_account?
      active?
    end

    def accepted_community_code_of_conduct?(version:)
      community_code_of_conduct_accepted_at.present? && community_code_of_conduct_version == version
    end

    def record_community_code_of_conduct_acceptance!(version:)
      raise Errors::Unavailable unless can_view_account?

      unless accepted_community_code_of_conduct?(version:)
        update!(community_code_of_conduct_version: version, community_code_of_conduct_accepted_at: Time.current)
      end
      self
    end

    def change_community_username!(community_username:)
      authorize_community_profile_change!

      update!(community_username: community_username || "")
    rescue ActiveRecord::RecordNotUnique => error
      constraint = error.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      raise unless constraint == "users_community_username_unique"

      errors.add(:community_username, :taken)
      raise ActiveRecord::RecordInvalid, self
    end

    def choose_community_avatar!(preset:)
      authorize_community_profile_change!

      transaction do
        update!(community_avatar_preset: preset || "")
        unless reload.community_avatar_preset == preset
          errors.add(:community_avatar_preset, :not_saved)
          raise ActiveRecord::RecordInvalid, self
        end
      end
    end

    def grant_superuser!(actor:)
      raise Identity::Errors::SuperuserRequired unless actor.superuser?
      raise Identity::Errors::SuperuserAlreadyGranted if superuser?

      update!(superuser: true)
      self
    end

    def revoke_superuser!(actor:)
      raise Identity::Errors::SuperuserRequired unless actor.superuser?
      raise Identity::Errors::SuperuserAlreadyRevoked unless superuser?

      update!(superuser: false)
      self
    end

    def can_reset_password?
      active? && email_confirmed_at.present?
    end

    def reset_password!(password:, password_confirmation:)
      raise Identity::Errors::PasswordResetUnavailable unless can_reset_password?

      UserRegistered.transaction do
        assign_attributes(password:, password_confirmation:)
        save!(context: :password_reset)
        Session.where(user_id: id).delete_all
        self
      end
    end

    def authorize_credential_change!(current_password:)
      return if current_password.is_a?(String) && current_password.bytesize <= 72 && authenticate(current_password)

      raise Errors::IncorrectCurrentPassword
    end

    def validate_new_email!(email_address:)
      address = self.class.normalize_value_for(:email_address, email_address)
      if !address.is_a?(String) || !URI::MailTo::EMAIL_REGEXP.match?(address)
        errors.add(:email_address, :invalid)
      elsif address == self.email_address || self.class.exists?(email_address: address)
        errors.add(:email_address, :taken)
      end
      raise ActiveRecord::RecordInvalid, self if errors.any?

      address
    end

    def email_change_version
      Digest::SHA256.hexdigest([ email_address, email_confirmed_at.iso8601(6), password_digest ].join(":"))
    end

    def change_email!(email_address:)
      transaction do
        update!(email_address: validate_new_email!(email_address:), email_confirmed_at: Time.current)
        Session.where(user_id: id).delete_all
      end
    end

    def self.authenticate_credentials(email_address:, password:)
      return unless email_address.is_a?(String) && password.is_a?(String)
      return if email_address.blank? || password.blank?

      email = normalize_value_for(:email_address, email_address)
      return unless URI::MailTo::EMAIL_REGEXP.match?(email)

      user = authenticate_by(email_address: email, password:)
      user if user&.active? && user.email_confirmed_at.present?
    end

    def session_duration
      20.years
    end

    def self.find_by_email(email)
      return unless email.is_a?(String)

      canonical_email = normalize_value_for(:email_address, email)
      return unless URI::MailTo::EMAIL_REGEXP.match?(canonical_email)

      find_by(email_address: canonical_email)
    end

    private

    def authorize_community_profile_change!
      raise Errors::Unavailable unless can_view_account?
      raise Errors::CommunityCodeOfConductRequired unless Community::CodeOfConduct.current.accepted_by?(member: self)
    end

    def community_username_is_not_reserved
      errors.add(:community_username, :reserved) if RESERVED_COMMUNITY_USERNAMES.include?(community_username&.downcase)
    end
  end
end

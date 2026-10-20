module Identity
  class CompleteRegistration
    def self.call(token:)
      raise RegistrationUnavailable unless token.is_a?(String) && token.present?

      candidate = PendingRegistration.find_by_token_for(:email_confirmation, token)
      raise RegistrationUnavailable if candidate.nil?

      PendingRegistration.transaction(requires_new: true) do
        # Preparation locks the source_user first too. Never reverse this order.
        source_user = User.lock.find_by(id: candidate.guest_user_id) if candidate.guest_user_id.present?
        registration = PendingRegistration.lock.find_by_token_for(:email_confirmation, token)
        unless registration.present? && registration.active? && registration.guest_user_id == candidate.guest_user_id &&
            (registration.guest_user_id.nil? || (source_user.present? && source_user.can_register?))
          raise RegistrationUnavailable
        end

        user = source_user.present? ? source_user.becomes!(UserRegistered) : UserRegistered.new
        user.assign_attributes(email_address: registration.email_address, password_digest: registration.password_digest,
          email_confirmed_at: Time.current)
        # The confirmed pending request supplies the validated digest. Ordinary
        # creation still requires plaintext password/confirmation; all common
        # validations and database constraints run in this explicit context.
        user.save!(context: :confirmed_registration)
        Session.where(user_id: user.id).delete_all if source_user.present?
        session = Session.create!(user: user)
        registration.destroy!
        session
      end
    rescue ActiveRecord::RecordInvalid => error
      if error.record.is_a?(UserRegistered) && error.record.errors.any? &&
          error.record.errors.all? { |entry| entry.attribute == :email_address && entry.type == :taken }
        raise RegistrationUnavailable, cause: nil
      end
      raise
    rescue ActiveRecord::RecordNotUnique => error
      constraint = error.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      raise RegistrationUnavailable, cause: nil if constraint == "index_users_on_email_address"

      raise
    end
  end
end

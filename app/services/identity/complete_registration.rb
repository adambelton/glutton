module Identity
  class CompleteRegistration
    def self.call(token:, current_user_id: nil, pending_registration_id: nil)
      candidate = PendingRegistration.resolve_confirmation!(token:)

      PendingRegistration.transaction(requires_new: true) do
        # Preparation and cleanup also lock the user before the pending request.
        source_user_id = current_user_id || candidate.guest_user_id
        source_user = User.lock.find_by(id: source_user_id) if source_user_id
        raise RegistrationConflict if current_user_id && source_user.nil?

        registration = PendingRegistration.lock.resolve_confirmation!(token:)
        raise RegistrationUnavailable unless registration.guest_user_id == candidate.guest_user_id

        if current_user_id
          registration.authorize_confirmation!(user: source_user, pending_registration_id:)
          registration.attach_to!(user: source_user) if registration.unattached?
        elsif registration.guest_user_id && !source_user&.can_register?
          raise RegistrationUnavailable
        end

        user = source_user.present? ? source_user.becomes!(UserRegistered) : UserRegistered.new
        user.assign_attributes(email_address: registration.email_address, password_digest: registration.password_digest,
          email_confirmed_at: Time.current)
        # The confirmed pending request supplies the validated digest. Ordinary
        # creation still requires plaintext password/confirmation; all common
        # validations and database constraints run in this explicit context.
        begin
          user.save!(context: :confirmed_registration)
        rescue ActiveRecord::RecordInvalid => error
          if error.record.equal?(user) && error.record.errors.any? &&
              error.record.errors.all? { |entry| entry.attribute == :email_address && entry.type == :taken }
            raise RegistrationUnavailable, cause: nil
          end
          raise
        end
        Session.where(user_id: user.id).delete_all if source_user.present?
        session = Session.create!(user: user)
        registration.destroy!
        session
      end
    rescue ActiveRecord::RecordNotUnique => error
      constraint = error.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      raise RegistrationUnavailable, cause: nil if constraint == "index_users_on_email_address"

      raise
    end
  end
end

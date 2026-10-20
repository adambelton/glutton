module Identity
  class CompleteRegistration
    def self.call(token:, current_user_id: nil, pending_registration_id: nil)
      candidate = PendingRegistration.resolve_confirmation!(token:)

      PendingRegistration.transaction(requires_new: true) do
        # Preparation and cleanup also lock the user before the pending request.
        if current_user_id
          current_user = User.lock.find_by(id: current_user_id)
          raise RegistrationConflict unless current_user

          registration = lock_registration(token:, candidate:)
          registration.authorize_confirmation!(user: current_user, pending_registration_id:)
          registration.attach_to!(user: current_user) if registration.unattached?
          source_user = current_user
        else
          source_user = User.lock.find_by(id: candidate.guest_user_id) if candidate.guest_user_id
          registration = lock_registration(token:, candidate:)
          raise RegistrationUnavailable if registration.guest_user_id && !source_user&.can_register?
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

    def self.lock_registration(token:, candidate:)
      registration = PendingRegistration.lock.resolve_confirmation!(token:)
      raise RegistrationUnavailable unless registration.guest_user_id == candidate.guest_user_id

      registration
    end
    private_class_method :lock_registration
  end
end

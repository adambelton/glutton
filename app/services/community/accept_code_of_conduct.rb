module Community
  class AcceptCodeOfConduct
    def self.call(user_id:, displayed_version:, accepted:)
      Identity::UserRegistered.transaction do
        member = Identity::UserRegistered.lock.find_by(id: user_id)
        raise Errors::MembershipRequired unless member&.can_view_account?

        code = CodeOfConduct.current
        raise Errors::CodeOfConductChanged unless displayed_version == code.version
        raise Errors::ExplicitAcceptanceRequired unless accepted

        CodeOfConductAcceptance.record!(member:, code:)
      end
    end
  end
end

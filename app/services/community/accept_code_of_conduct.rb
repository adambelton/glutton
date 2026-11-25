module Community
  class AcceptCodeOfConduct
    def self.call(user_id:, displayed_version:, accepted:)
      Identity::AccountAdministration::ManageRegisteredAccount.new(user_id:).record_community_code_of_conduct_acceptance do |account|
        PreviewAccess.require!(user: account)
        code = CodeOfConduct.current
        raise Errors::CodeOfConductChanged unless displayed_version == code.version
        raise Errors::ExplicitAcceptanceRequired unless accepted

        code.version
      end
    rescue Identity::Errors::Unavailable
      raise Errors::MembershipRequired
    end
  end
end

module Identity
  class SuperuserAlreadyRevoked < StandardError
    def initialize
      super(I18n.t("identity.superuser.already_revoked"))
    end
  end
end

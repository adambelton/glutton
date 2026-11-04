module Identity
  class SuperuserAlreadyGranted < StandardError
    def initialize
      super(I18n.t("identity.superuser.already_granted"))
    end
  end
end

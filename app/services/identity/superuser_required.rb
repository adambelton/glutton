module Identity
  class SuperuserRequired < StandardError
    def initialize
      super(I18n.t("identity.superuser.required"))
    end
  end
end

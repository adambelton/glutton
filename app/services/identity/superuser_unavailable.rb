module Identity
  class SuperuserUnavailable < StandardError
    def initialize
      super(I18n.t("identity.superuser.unavailable"))
    end
  end
end

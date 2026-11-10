module Identity
  module Errors
    class SuperuserRequired < StandardError
      def initialize
        super(I18n.t("identity.superuser.required"))
      end
    end
  end
end

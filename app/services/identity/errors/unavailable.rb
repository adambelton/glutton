module Identity
  module Errors
    class Unavailable < StandardError
      def message
        I18n.t("identity.errors.unavailable")
      end
    end
  end
end

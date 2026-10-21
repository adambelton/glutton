module Ratings
  class IdentityUnavailable < StandardError
    def message
      I18n.t("ratings.errors.identity_unavailable")
    end
  end
end

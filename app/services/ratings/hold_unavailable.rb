module Ratings
  class HoldUnavailable < StandardError
    def message
      I18n.t("ratings.errors.hold_unavailable")
    end
  end
end

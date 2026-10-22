module Ratings
  class HoldReleaseUnavailable < StandardError
    def message
      I18n.t("ratings.errors.hold_release_unavailable")
    end
  end
end

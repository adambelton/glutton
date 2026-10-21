module Ratings
  class DismissalUnavailable < StandardError
    def message
      I18n.t("ratings.errors.dismissal_unavailable")
    end
  end
end

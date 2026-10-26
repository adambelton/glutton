module Ratings
  class StaleRating < StandardError
    def message
      I18n.t("ratings.errors.stale_rating")
    end
  end
end

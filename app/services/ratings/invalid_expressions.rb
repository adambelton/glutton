module Ratings
  class InvalidExpressions < StandardError
    def message
      I18n.t("ratings.errors.invalid_expressions", count: Rating::MAX_EXPRESSIONS)
    end
  end
end

module Ratings
  class InvalidNotes < StandardError
    def message
      I18n.t("ratings.errors.invalid_notes")
    end
  end
end

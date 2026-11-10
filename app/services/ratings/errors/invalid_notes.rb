module Ratings
  module Errors
    class InvalidNotes < StandardError
      def message
        I18n.t("ratings.errors.invalid_notes")
      end
    end
  end
end

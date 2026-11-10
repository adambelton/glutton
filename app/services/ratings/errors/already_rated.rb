module Ratings
  module Errors
    class AlreadyRated < StandardError
      def message
        I18n.t("ratings.errors.already_rated")
      end
    end
  end
end

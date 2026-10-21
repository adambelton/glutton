module Ratings
  class FilmUnavailable < StandardError
    def message
      I18n.t("ratings.errors.film_unavailable")
    end
  end
end

module Ratings
  class RevisionUnavailable < StandardError
    def message
      I18n.t("ratings.errors.revision_unavailable")
    end
  end
end

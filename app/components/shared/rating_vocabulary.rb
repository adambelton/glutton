module Shared
  class RatingVocabulary
    attr_reader :key

    def initialize(key)
      @key = if Identity::RatingVocabularies::ALL.include?(key)
        key
      else
        Identity::RatingVocabularies::INTERNATIONAL
      end
    end

    def name
      I18n.t("rating_vocabulary.names.#{key}", raise: true)
    end

    def label(value)
      scope = if key == Identity::RatingVocabularies::INTERNATIONAL
        "ratings.values"
      else
        "rating_vocabulary.labels.#{key}"
      end
      I18n.t("#{scope}.#{value}", raise: true)
    end

    def labels
      Ratings::Rating::Values::ALL.index_with { |value| label(value) }
    end
  end
end

module Identity
  class RatingVocabularySymbol < Shared::Base
    include Phlex::Rails::Helpers::ImagePath

    EMOJI = {
      RatingVocabularies::INTERNATIONAL => "🌐",
      RatingVocabularies::ENGLAND => "\u{1F3F4 E0067 E0062 E0065 E006E E0067 E007F}",
      RatingVocabularies::SCOTLAND => "\u{1F3F4 E0067 E0062 E0073 E0063 E0074 E007F}",
      RatingVocabularies::WALES => "\u{1F3F4 E0067 E0062 E0077 E006C E0073 E007F}",
      RatingVocabularies::IRELAND => "🇮🇪",
      RatingVocabularies::UNITED_STATES => "🇺🇸",
      RatingVocabularies::CANADA => "🇨🇦",
      RatingVocabularies::AUSTRALIA => "🇦🇺",
      RatingVocabularies::NEW_ZEALAND => "🇳🇿",
      RatingVocabularies::SOUTH_AFRICA => "🇿🇦"
    }.freeze

    def initialize(vocabulary:, **attrs)
      @vocabulary = vocabulary
      @attrs = attrs
    end

    def view_template
      span(class: "rating-vocabulary-symbol", aria: { hidden: true }, **@attrs) do
        if @vocabulary.key == RatingVocabularies::SCOUSE
          img(src: image_path("rating-vocabulary-lfc-liver-bird.svg"), alt: "", width: 20, height: 22,
            class: "rating-vocabulary-liver-bird", data: { symbol: "liver-bird" })
        else
          plain EMOJI.fetch(@vocabulary.key)
        end
      end
    end
  end
end

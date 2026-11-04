module FilmKnowledge
  class InvalidFilmLoad < ArgumentError
    attr_reader :reason

    def initialize(reason:)
      @reason = reason
      super(I18n.t("film_knowledge.loading.errors.#{reason}"))
    end
  end
end

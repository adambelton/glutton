module FilmKnowledge
  class GenerationUnavailable < StandardError
    def message
      I18n.t("film_knowledge.errors.generation_unavailable")
    end
  end
end

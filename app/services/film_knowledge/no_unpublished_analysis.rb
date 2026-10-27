module FilmKnowledge
  class NoUnpublishedAnalysis < StandardError
    def message
      I18n.t("film_knowledge.errors.no_unpublished_analysis")
    end
  end
end

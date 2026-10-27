module FilmKnowledge
  class AnalysisNotEditable < StandardError
    def message
      I18n.t("film_knowledge.errors.analysis_not_editable")
    end
  end
end

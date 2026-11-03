module FilmKnowledge
  class ImportIncomplete < StandardError
    attr_reader :stage, :reason, :tmdb_id

    def initialize(stage:, reason:, tmdb_id: nil)
      @stage, @reason, @tmdb_id = stage, reason, tmdb_id
      super(I18n.t("film_knowledge.import.incomplete",
        stage: I18n.t("film_knowledge.import.stages.#{stage}"),
        reason: I18n.t("film_knowledge.import.reasons.#{reason}")))
    end
  end
end

module FilmKnowledge
  class AssignInitialFilmQualitiesJob < ApplicationJob
    def perform(film_ids:)
      warnings = []
      assigned = []
      film_ids.each do |film_id|
        begin
          result = AssignInitialFilmQualities.call(film_id:)
          count = result.fetch(:film_qualities).size
          if count.zero?
            warnings << report_warning(film_id:, reason: :no_qualities)
          else
            assigned << film_id
          end
        rescue AssignmentFailed => error
          warnings << report_warning(film_id:, reason: :assessment_failed, detail: error.message)
        rescue StandardError
          # A failed film must not discard the rest of the batch. Keep exception text private.
          warnings << report_warning(film_id:, reason: :unexpected_failure)
        end
      end
      { assigned_film_ids: assigned, warnings: }
    end

    private

    def report_warning(film_id:, reason:, detail: nil)
      warning = { film_id:, reason:, message: I18n.t("film_knowledge.assignment.warnings.#{reason}", film_id:, detail:) }
      Rails.logger.warn(warning.to_json)
      warning
    end
  end
end

module FilmKnowledge
  class PublishAnalysis
    def self.call(film_id:)
      FilmAnalysis.transaction(requires_new: true) do
        film = Film.lock.find(film_id)
        film_analysis = film.film_analyses.draft.first
        raise NoUnpublishedAnalysis unless film_analysis
        film_analysis.ensure_editable!
        film_analysis.validate_for_publication!

        film_analysis.quality_proposals.each do |quality_candidate|
          film_quality = FilmQuality.find_or_create!(quality_candidate:)
          film_analysis.add_quality!(film_quality:, evidence_references: quality_candidate.evidence_references)
        end

        timestamp = Time.current.floor(6)
        film.film_analyses.current.first&.supersede!(replacement: film_analysis, at: timestamp)
        film_analysis.publish!(at: timestamp)
        film_analysis
      rescue ActiveModel::ValidationError
        film_analysis.errors.add(:quality_candidates, :invalid)
        raise ActiveRecord::RecordInvalid.new(film_analysis)
      end
    end
  end
end

module Recommendations
  module CandidateSelection
    class RankFilms
      Candidate = Data.define(:film_id, :score, :contributions)

      def self.call(film_ids:, quality_ids_by_film:, scores_by_quality:)
        film_ids.map do |film_id|
          contributions = quality_ids_by_film.fetch(film_id, []).uniq.to_h do |quality_id|
            [ quality_id, scores_by_quality.fetch(quality_id, 0) ]
          end
          Candidate.new(film_id:, score: contributions.values.sum, contributions:)
        end.min_by { |candidate| [ -candidate.score, candidate.film_id ] }
      end
    end
  end
end

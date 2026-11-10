module Ratings
  module CandidateSelection
    class NextCandidates
      def self.call(user_id:, limit: 1)
        ReplenishCandidateQueue.call(user_id:, limit:) do |queued_film_ids, shortfall|
          Registry::CatalogueQueries::FilmIdsByTmdbVoteCount.call(excluding_ids: queued_film_ids, limit: shortfall)
        end
      end
    end
  end
end

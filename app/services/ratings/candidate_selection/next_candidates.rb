module Ratings
  module CandidateSelection
    class NextCandidates
      def self.call(user_id:, limit: 1, excluding_film_id: nil)
        unless limit.is_a?(Integer) && (1..100).cover?(limit)
          raise ArgumentError, "limit must be an integer from 1 to 100"
        end

        RatingFilm.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless user&.active?

          ReplenishCandidateQueue.call(user:, limit:, excluding_film_id:) do |queued_film_ids, shortfall|
            Registry::CatalogueQueries::FilmIdsByTmdbVoteCount.call(excluding_ids: queued_film_ids, limit: shortfall)
          end
        end
      end
    end
  end
end

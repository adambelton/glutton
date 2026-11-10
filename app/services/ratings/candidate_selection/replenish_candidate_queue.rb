module Ratings
  module CandidateSelection
    class ReplenishCandidateQueue
      def self.call(user_id:, limit:)
        unless limit.is_a?(Integer) && (1..100).cover?(limit)
          raise ArgumentError, "limit must be an integer from 1 to 100"
        end

        RatingFilm.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless user&.active?

          candidates = RatingFilm.where(user_id: user.id).pending
            .order(:created_at, :id).limit(limit).to_a
          shortfall = limit - candidates.size
          if shortfall.positive?
            queued_film_ids = RatingFilm.where(user_id: user.id).pluck(:film_id)
            yield(queued_film_ids, shortfall).each do |film_id|
              candidates << RatingFilm.create!(user:, film_id:)
            end
          end
          candidates
        end
      end
    end
  end
end

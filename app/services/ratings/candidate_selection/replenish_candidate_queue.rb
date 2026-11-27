module Ratings
  module CandidateSelection
    class ReplenishCandidateQueue
      # The caller must hold the active account's row lock through this operation.
      def self.call(user:, limit:, excluding_film_id: nil)
        pending = RatingFilm.where(user_id: user.id).pending
        pending = pending.where.not(film_id: excluding_film_id) if excluding_film_id.present?
        candidates = pending.order(:created_at, :id).limit(limit).to_a
        shortfall = limit - candidates.size
        if shortfall.positive?
          queued_film_ids = RatingFilm.where(user_id: user.id).pluck(:film_id)
          queued_film_ids |= [ excluding_film_id ] if excluding_film_id.present?
          film_ids = yield(queued_film_ids, shortfall)
          film_ids.each do |film_id|
            candidates << RatingFilm.create!(user:, film_id:)
          end
          ActivityMonitoring.current_operation_span&.set_operation(ActivityMonitoring::Operations::CREATE_RATING_FILM) if film_ids.present?
        end
        candidates
      end
    end
  end
end

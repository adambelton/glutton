module Ratings
  class NextCandidates
    def self.call(user_id:, limit: 5)
      unless limit.is_a?(Integer) && (1..100).cover?(limit)
        raise ArgumentError, "limit must be an integer from 1 to 100"
      end

      RatingFilm.transaction(requires_new: true) do
        user = User.lock.find_by(id: user_id)
        raise IdentityUnavailable unless user&.active?

        RatingFilm.where(user_id: user.id).pending.order(:created_at, :id).limit(limit).to_a
      end
    end
  end
end

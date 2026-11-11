module Recommendations
  module EventHandlers
    module Ratings
      class RatingSubmitted
        def self.call(recommendation_film:)
          recommendation_film.suppress!
        end
      end
    end
  end
end

module Ratings
  module RatingRecording
    class FindRevisionBaseline
      def self.call(user_id:, rating_film_id:, previous_rating_id:)
        rating_film = CandidateSelection::FindCandidate.call(user_id:, rating_film_id:)
        [ rating_film, rating_film.ratings.find_by(id: previous_rating_id) ]
      end
    end
  end
end

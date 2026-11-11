module Recommendations
  class RecordFilmResponse
    def self.call(user_id:, film_id:, response:)
      raise ArgumentError, "Invalid recommendation response" unless RecommendationFilm::Responses::ALL.include?(response)

      RecommendationFilm.transaction(requires_new: true) do
        user = Identity::User.lock.find_by(id: user_id)
        raise Identity::Errors::Unavailable unless user&.active?

        film = Registry::Film.find_by(id: film_id)
        raise Errors::ResponseUnavailable unless film.present?

        recommendation_film = RecommendationFilm.lock.find_or_initialize_by(user:, film:)
        recommendation_film.record_response!(response:)
        if response == RecommendationFilm::Responses::ACCEPTED
          payload = { user_id: user.id, film_id: film.id, recommendation_film_id: recommendation_film.id }

          DomainEvents::Publication::Publish.call(user_id: user.id, publisher: Events::PUBLISHING_DOMAIN,
            stream_key: "film:#{film.id}", name: Events::RECOMMENDATION_ACCEPTED, payload:)
        end
        recommendation_film
      end
    end
  end
end

class RecommendationsController < ApplicationController
  rescue_from Identity::Errors::Required, Identity::Errors::Unavailable do
    head :unauthorized
  end

  def show
    watched_film_id = flash[:recommendations_excluded_film_id]
    flash.delete(:recommendations_excluded_film_id)
    result = Recommendations::CandidateSelection::NextCandidate.call(user_id: current_user.id, excluding_film_id: watched_film_id)
    render ::Views::Recommendations::Show.new(result:, film: result.film, watched_film_id:)
  end
end

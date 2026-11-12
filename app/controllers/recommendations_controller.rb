class RecommendationsController < ApplicationController
  rescue_from Identity::Errors::Required, Identity::Errors::Unavailable do
    head :unauthorized
  end

  rescue_from Recommendations::Errors::ResponseUnavailable do
    render ::Views::Recommendations::Unavailable.new(message: I18n.t("recommendations.response_unavailable")), status: :conflict
  end

  def show
    watched_film_id = flash[:recommendations_excluded_film_id]
    flash.delete(:recommendations_excluded_film_id)
    result = Recommendations::CandidateSelection::NextCandidate.call(user_id: current_user.id, excluding_film_id: watched_film_id)
    render ::Views::Recommendations::Show.new(result:, film: result.film, watched_film_id:)
  end

  def accept
    record_response(Recommendations::RecommendationFilm::Responses::ACCEPTED)
  end

  def reject
    record_response(Recommendations::RecommendationFilm::Responses::REJECTED)
  end

  private

  def record_response(response)
    film_id = params[:film_id]
    unless film_id.is_a?(String) && film_id.match?(/\A[1-9]\d{0,18}\z/)
      render ::Views::Recommendations::Unavailable.new(message: I18n.t("recommendations.invalid_film")), status: :bad_request
      return
    end

    Recommendations::RecordFilmResponse.call(user_id: current_user.id, film_id: film_id.to_i, response:)
    redirect_to recommendation_path, notice: I18n.t("recommendations.responses.#{response}"), status: :see_other
  end
end

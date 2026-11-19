class RecommendationsController < ApplicationController
  rescue_from Identity::Errors::Required, Identity::Errors::Unavailable do
    head :unauthorized
  end

  rescue_from Recommendations::Errors::ResponseUnavailable do
    render ::Views::Recommendations::Unavailable.new(message: I18n.t("recommendations.response_unavailable")), status: :conflict
  end

  def show
    excluded_film_id = flash[:recommendations_excluded_film_id]
    flash.delete(:recommendations_excluded_film_id)
    result = Recommendations::CandidateSelection::NextRecommendation.call(user_id: current_user.id, excluding_film_id: excluded_film_id)
    @business_activity = result.assessed_film_count.to_i >= Recommendations::CandidateSelection::NextCandidate::MINIMUM_ASSESSED_FILMS
    render ::Views::Recommendations::Show.new(result:)
  end

  def availability
    no_store
    unlocked = Recommendations::CandidateSelection::RecommendationUnlock.unlocked?(user: current_user)
    head(unlocked ? :no_content : :accepted)
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
    flash[:notice] = I18n.t("recommendations.responses.accepted") if response == Recommendations::RecommendationFilm::Responses::ACCEPTED
    redirect_to recommendation_path, status: :see_other
  end
end

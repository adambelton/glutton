module Ratings
  class CandidatesController < ApplicationController
    before_action :require_identity
    before_action :load_candidate, only: [ :rate, :dismiss ]

    rescue_from IdentityUnavailable do
      render :signed_out, status: :unauthorized
    end
    rescue_from FilmUnavailable do |error|
      @error = error.message
      render :unavailable, status: :not_found
    end
    rescue_from AlreadyRated, DismissalUnavailable do |error|
      @error = error.message
      render :unavailable, status: :conflict
    end

    def index
      @rating_film = NextCandidates.call(user_id: current_user.id, limit: 1).first
      @expression_texts = []
    end

    def rate
      @value = params[:value] if params[:value].is_a?(String)
      @expression_texts = []
      texts = params.fetch(:expression_texts, [])
      unless texts.is_a?(Array) && texts.size <= Rating::MAX_EXPRESSIONS && texts.all? { |text| text.is_a?(String) }
        raise InvalidExpressions
      end
      @expression_texts = texts
      SubmitRating.call(user_id: current_user.id, rating_film_id: @rating_film.id,
        value: @value, expression_texts: texts.reject(&:blank?))
      redirect_to ratings_candidates_path, notice: I18n.t("ratings.browser.saved"), status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @errors = error.record.errors.full_messages
      render :index, status: :unprocessable_entity
    rescue InvalidExpressions => error
      @errors = [ error.message ]
      render :index, status: :unprocessable_entity
    end

    def dismiss
      Dismiss.call(user_id: current_user.id, rating_film_id: @rating_film.id)
      redirect_to ratings_candidates_path, notice: I18n.t("ratings.browser.dismissed"), status: :see_other
    end

    private

    def require_identity
      raise IdentityUnavailable unless current_user
    end

    def load_candidate
      # Route IDs are untrusted; do not allow integer coercion to select another row.
      id = params[:id]
      raise FilmUnavailable unless id.is_a?(String) && id.match?(/\A[1-9]\d*\z/)

      @rating_film = RatingFilm.find_by(id: id, user_id: current_user.id)
      raise FilmUnavailable unless @rating_film
    end
  end
end

module Ratings
  class RatingsController < ::ApplicationController
    before_action :require_identity

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

    def new
      @expression_texts = []
      if params.key?(:film_id)
        @rating_film = PrepareCandidate.call(user_id: current_user.id, film_id: film_id_param)
      else
        @rating_film = NextCandidates.call(user_id: current_user.id, limit: 1).first
      end
    end

    def create
      @value = params[:value] if params[:value].is_a?(String)
      @expression_texts = []
      texts = params.fetch(:expression_texts, [])
      unless texts.is_a?(Array) && texts.size <= Rating::MAX_EXPRESSIONS && texts.all? { |text| text.is_a?(String) }
        raise InvalidExpressions
      end
      @expression_texts = texts
      SubmitRating.call(user_id: current_user.id, rating_film_id: rating_film_id_param,
        value: @value, expression_texts: texts.reject(&:blank?))
      redirect_to new_rating_path, notice: I18n.t("ratings.browser.saved"), status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @errors = error.record.errors.full_messages
      render_invalid_rating
    rescue InvalidExpressions => error
      @errors = [ error.message ]
      render_invalid_rating
    end

    def dismiss
      Dismiss.call(user_id: current_user.id, rating_film_id: rating_film_id_param)
      redirect_to new_rating_path, notice: I18n.t("ratings.browser.dismissed"), status: :see_other
    end

    private

    def require_identity
      raise IdentityUnavailable unless current_user
    end

    def film_id_param
      id = params[:film_id]
      raise FilmUnavailable unless id.is_a?(String) && id.match?(/\A[1-9]\d*\z/)

      id
    end

    def rating_film_id_param
      id = params[:rating_film_id]
      raise FilmUnavailable unless id.is_a?(String) && id.match?(/\A[1-9]\d*\z/)

      id
    end

    def render_invalid_rating
      @rating_film = FindCandidate.call(user_id: current_user.id, rating_film_id: rating_film_id_param)
      render :new, status: :unprocessable_entity
    end
  end
end

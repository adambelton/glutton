class RatingsController < ApplicationController
  before_action :require_identity

  rescue_from Identity::Required, Ratings::IdentityUnavailable do
    render :signed_out, status: :unauthorized
  end
  rescue_from Ratings::FilmUnavailable do |error|
    @error = error.message
    render :unavailable, status: :not_found
  end
  rescue_from Ratings::AlreadyRated, Ratings::DismissalUnavailable, Ratings::RevisionUnavailable do |error|
    @error = error.message
    render :unavailable, status: :conflict
  end

  def new
    @expression_texts = []
    if params.key?(:film_id)
      @rating_film = Ratings::PrepareCandidate.call(user_id: current_user.id, film_id: film_id_param)
    else
      @rating_film = Ratings::NextCandidates.call(user_id: current_user.id, limit: 1).first
    end
  end

  def create
    read_rating_input
    rating = Ratings::SubmitRating.call(user_id: current_user.id, rating_film_id: rating_film_id_param,
      value: @value, expression_texts: @expression_texts.reject(&:blank?))
    flash[:edited_film] = { id: rating.rating_film.film_id, title: rating.rating_film.film.title }
    redirect_to new_rating_path, notice: I18n.t("ratings.browser.saved"), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @errors = error.record.errors.full_messages
    render_invalid_rating
  rescue Ratings::InvalidExpressions => error
    @errors = [ error.message ]
    render_invalid_rating
  end

  def edit
    rating = Ratings::FindCurrentRating.call(user_id: current_user.id, film_id: film_id_param)
    @rating_film = rating.rating_film
    @previous_rating_id = rating.id
    @value = rating.value
    @expression_texts = rating.rating_expressions.map(&:text)
  end

  def update
    @previous_rating_id = previous_rating_id_param
    read_rating_input
    rating = Ratings::ReviseRating.call(user_id: current_user.id, rating_film_id: rating_film_id_param,
      previous_rating_id: @previous_rating_id, value: @value, expression_texts: @expression_texts.reject(&:blank?))
    redirect_to edit_rating_path(film_id: rating.rating_film.film_id),
      notice: I18n.t("ratings.browser.updated"), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @errors = error.record.errors.full_messages
    render_invalid_revision
  rescue Ratings::InvalidExpressions => error
    @errors = [ error.message ]
    render_invalid_revision
  rescue Ratings::StaleRating => error
    @rating_film = Ratings::FindCandidate.call(user_id: current_user.id, rating_film_id: rating_film_id_param)
    @error = error.message
    render :stale, status: :conflict
  end

  def dismiss
    Ratings::Dismiss.call(user_id: current_user.id, rating_film_id: rating_film_id_param)
    redirect_to new_rating_path, notice: I18n.t("ratings.browser.dismissed"), status: :see_other
  end

  private

  def read_rating_input
    @value = params[:value] if params[:value].is_a?(String)
    @expression_texts = []
    texts = params.fetch(:expression_texts, [])
    unless texts.is_a?(Array) && texts.size <= Rating::MAX_EXPRESSIONS && texts.all? { |text| text.is_a?(String) }
      raise Ratings::InvalidExpressions
    end
    @expression_texts = texts
  end

  def previous_rating_id_param
    id = params[:previous_rating_id]
    raise Ratings::StaleRating unless id.is_a?(String) && id.match?(/\A[1-9]\d*\z/)

    id.to_i
  end

  def render_invalid_revision
    @rating_film = Ratings::FindCandidate.call(user_id: current_user.id, rating_film_id: rating_film_id_param)
    render :edit, status: :unprocessable_entity
  end

  def film_id_param
    id = params[:film_id]
    raise Ratings::FilmUnavailable unless id.is_a?(String) && id.match?(/\A[1-9]\d*\z/)

    id.to_i
  end

  def rating_film_id_param
    id = params[:rating_film_id]
    raise Ratings::FilmUnavailable unless id.is_a?(String) && id.match?(/\A[1-9]\d*\z/)

    id.to_i
  end

  def render_invalid_rating
    @rating_film = Ratings::FindCandidate.call(user_id: current_user.id, rating_film_id: rating_film_id_param)
    render :new, status: :unprocessable_entity
  end
end

class RatingsController < ApplicationController
  rescue_from Identity::Errors::Required, Identity::Errors::Unavailable do
    render ::Views::Ratings::SignedOut.new, status: :unauthorized
  end
  rescue_from Ratings::Errors::FilmUnavailable do |error|
    @error = error.message
    render ::Views::Ratings::Unavailable.new(error: @error), status: :not_found
  end
  rescue_from Ratings::Errors::AlreadyRated, Ratings::Errors::DismissalUnavailable, Ratings::Errors::RevisionUnavailable do |error|
    @error = error.message
    render ::Views::Ratings::Unavailable.new(error: @error), status: :conflict
  end

  def new
    @targeted = params.key?(:film_id)
    if @targeted
      @rating_film = Ratings::CandidateSelection::PrepareCandidate.call(user_id: current_user.id, film_id: film_id_param)
    else
      excluding_film_id = flash[:ratings_excluded_film_id]
      flash.delete(:ratings_excluded_film_id)
      @rating_film = Ratings::CandidateSelection::NextCandidates.call(user_id: current_user.id, excluding_film_id:).first
    end
    render_new
  end

  def create
    @targeted = params[:targeted] == "1"
    read_rating_input
    Ratings::RatingRecording::SubmitRating.call(user_id: current_user.id, rating_film_id: rating_film_id_param,
      value: @value, notes: @notes)
    redirect_to new_rating_path, notice: I18n.t("ratings.browser.saved"), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @errors = error.record.errors.full_messages
    render_invalid_rating
  rescue Ratings::Errors::InvalidNotes => error
    @errors = [ error.message ]
    render_invalid_rating
  end

  def edit
    rating = Ratings::RatingRecording::FindCurrentRating.call(user_id: current_user.id, film_id: film_id_param)
    @rating_film = rating.rating_film
    @previous_rating_id = rating.id
    @value = rating.value
    @notes = rating.notes
    render_edit
  end

  def update
    @previous_rating_id = previous_rating_id_param
    read_rating_input
    rating = Ratings::RatingRecording::ReviseRating.call(user_id: current_user.id, rating_film_id: rating_film_id_param,
      previous_rating_id: @previous_rating_id, value: @value, notes: @notes)
    redirect_to edit_rating_path(film_id: rating.rating_film.film_id),
      notice: I18n.t("ratings.browser.updated"), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @errors = error.record.errors.full_messages
    render_invalid_revision
  rescue Ratings::Errors::InvalidNotes => error
    @errors = [ error.message ]
    render_invalid_revision
  rescue Ratings::Errors::StaleRating => error
    @rating_film = Ratings::CandidateSelection::FindCandidate.call(user_id: current_user.id, rating_film_id: rating_film_id_param)
    @error = error.message
    render ::Views::Ratings::Stale.new(error: @error, rating_film: @rating_film), status: :conflict
  end

  def dismiss
    Ratings::CandidateSelection::Dismiss.call(user_id: current_user.id, rating_film_id: rating_film_id_param)
    redirect_to new_rating_path, notice: I18n.t("ratings.browser.dismissed"), status: :see_other
  end

  private

  def render_new(status: :ok)
    render ::Views::Ratings::New.new(rating_film: @rating_film, targeted: @targeted,
      value: @value, notes: @notes, errors: @errors), status:
  end

  def render_edit(status: :ok)
    render ::Views::Ratings::Edit.new(rating_film: @rating_film, previous_rating_id: @previous_rating_id,
      value: @value, notes: @notes, errors: @errors), status:
  end

  def read_rating_input
    @value = params[:value] if params[:value].is_a?(String)
    notes = params.fetch(:notes, "")
    raise Ratings::Errors::InvalidNotes unless notes.is_a?(String)

    @notes = notes
  end

  def previous_rating_id_param
    id = params[:previous_rating_id]
    raise Ratings::Errors::StaleRating unless id.is_a?(String) && id.match?(/\A[1-9]\d*\z/)

    id.to_i
  end

  def render_invalid_revision
    @rating_film = Ratings::CandidateSelection::FindCandidate.call(user_id: current_user.id, rating_film_id: rating_film_id_param)
    render_edit(status: :unprocessable_entity)
  end

  def film_id_param
    id = params[:film_id]
    raise Ratings::Errors::FilmUnavailable unless id.is_a?(String) && id.match?(/\A[1-9]\d*\z/)

    id.to_i
  end

  def rating_film_id_param
    id = params[:rating_film_id]
    raise Ratings::Errors::FilmUnavailable unless id.is_a?(String) && id.match?(/\A[1-9]\d*\z/)

    id.to_i
  end

  def render_invalid_rating
    @rating_film = Ratings::CandidateSelection::FindCandidate.call(user_id: current_user.id, rating_film_id: rating_film_id_param)
    render_new(status: :unprocessable_entity)
  end
end

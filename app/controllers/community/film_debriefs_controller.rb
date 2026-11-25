module Community
  class FilmDebriefsController < ApplicationController
    rescue_from Errors::MembershipRequired, Errors::PostingUnavailable, with: -> { head :forbidden }
    rescue_from Errors::FilmDebriefUnavailable, ActiveRecord::RecordNotFound, with: -> { head :not_found }

    def show
      debrief = BrowseFilmDebriefs.detail(viewer: current_user, film_id:)
      render Views::Community::FilmDebrief.new(debrief:)
    end

    def create
      debrief = OpenFilmDebrief.call(member_id: current_user.id, film_id:)
      redirect_to community_film_debrief_path(debrief.film_id), status: :see_other
    end

    private

    def film_id
      value = params[:film_id]
      raise ActionController::BadRequest unless FilmId.valid?(value)

      value.to_i
    end
  end
end

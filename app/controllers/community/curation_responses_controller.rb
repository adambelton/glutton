module Community
  class CurationResponsesController < ApplicationController
    before_action :require_preview_access
    rescue_from Errors::PostingUnavailable, with: -> { head :forbidden }

    def new
      selection = EndorseCurationFilms.load_for_endorsement(curation_id: params[:curation_id], member: current_user)
      render Views::Community::NewCurationResponse.new(**selection)
    end

    def create
      fields = params.fetch(:response) { ActionController::Parameters.new }
      raise ActionController::BadRequest unless fields.is_a?(ActionController::Parameters)

      film_ids, comments = CurationFilmSelectionParameters.parse(ids: fields[:film_ids], comments: fields[:comments])
      curation = EndorseCurationFilms.call(curation_id: params[:curation_id], member_id: current_user.id, film_ids:, comments:)
      if curation.errors.any?
        films = EndorseCurationFilms.choices(curation:, member: current_user)
        return render Views::Community::NewCurationResponse.new(curation:, films:, film_ids:, comments:), status: :unprocessable_content
      end

      redirect_to community_curation_path(curation), notice: t("community.curation_responses.published"), status: :see_other
    end

    private

    def require_preview_access
      head :forbidden unless PreviewAccess.allowed?(user: current_user)
    end
  end
end

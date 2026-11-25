module Community
  class CurationEndorsementsController < ApplicationController
    before_action :require_posting_access
    rescue_from Errors::PostingUnavailable, with: -> { head :forbidden }

    def edit
      editor = Curations::EditCurationEndorsements.load_for_edit(curation_id: params[:curation_id], member: current_user)
      render_editor(editor)
    end

    def update
      fields = params[:endorsements]
      raise ActionController::BadRequest unless fields.is_a?(ActionController::Parameters) && fields[:snapshot].is_a?(String)

      film_ids, comments = CurationFilmSelectionParameters.parse(ids: fields[:film_ids], comments: fields[:comments])
      editor = Curations::EditCurationEndorsements.call(curation_id: params[:curation_id], member_id: current_user.id,
        film_ids:, comments:, snapshot: fields[:snapshot])
      curation = editor.fetch(:curation)
      if curation.errors.any?
        return render_editor(editor, status: editor.fetch(:stale) ? :conflict : :unprocessable_content)
      end

      notice = t("community.curation_endorsements.saved")
      if turbo_frame_request?
        flash[:notice] = notice
        return render turbo_stream: turbo_stream.refresh(request_id: nil)
      end

      redirect_to community_curation_path(curation), notice:, status: :see_other
    end

    private

    def require_posting_access
      head :forbidden unless Membership::PostingAccess.allowed?(user: current_user)
    end

    def render_editor(editor, status: :ok)
      render Views::Community::EditCurationEndorsements.new(**editor, dialog: turbo_frame_request?), status:, content_type: Mime[:html]
    end
  end
end

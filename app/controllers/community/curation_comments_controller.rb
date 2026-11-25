module Community
  class CurationCommentsController < ApplicationController
    before_action :require_member_access
    rescue_from Errors::CommentChangeUnavailable, with: -> { head :forbidden }

    def edit
      composer = Discussions::ManageCurationComment.load_for_edit(curation_id: params[:curation_id], comment_id: params[:id], member: current_user)
      render_composer(composer)
    end

    def update
      body = params[:body]
      raise ActionController::BadRequest unless body.nil? || body.is_a?(String)

      composer = Discussions::ManageCurationComment.edit(curation_id: params[:curation_id], comment_id: params[:id], member_id: current_user.id, body:)
      return render_composer(composer, status: :unprocessable_content) if composer.fetch(:content).errors.any?

      curation, comment = composer.values_at(:curation, :comment)
      if turbo_frame_request?
        return render Views::Community::DiscussionCommentEdited.new(routes: CurationDiscussionRoutes.new(curation:), comment:, can_reply: Membership::PostingAccess.allowed?(user: current_user)),
          content_type: Mime[:turbo_stream]
      end

      redirect_to community_curation_path(curation, reply: comment.id, anchor: "comment-#{comment.id}"),
        notice: t("community.comment_editing.saved"), status: :see_other
    end

    def destroy
      removal = Discussions::ManageCurationComment.delete(curation_id: params[:curation_id], comment_id: params[:id], member_id: current_user.id)
      curation, film_id, selected_comment_id, nomination_visible = removal.values_at(:curation, :film_id, :selected_comment_id, :nomination_visible)
      if request.format.turbo_stream? && nomination_visible
        discussion = Discussions::CurationDiscussion.new(curation:, film_id:, selected_reply_id: selected_comment_id, expand_selected_branch: true)
        return render Views::Community::CurationFilmDiscussionUpdate.new(curation:, film_id:, discussion:,
          can_reply: Membership::PostingAccess.allowed?(user: current_user)), content_type: Mime[:turbo_stream]
      end

      unless nomination_visible
        return redirect_to community_curation_path(curation), notice: t("community.comment_deletion.deleted"), status: :see_other
      end

      anchor = selected_comment_id.present? ? "comment-#{selected_comment_id}" : "nomination-#{film_id}"
      redirect_to community_curation_path(curation, reply: selected_comment_id, anchor:),
        notice: t("community.comment_deletion.deleted"), status: :see_other
    end

    private

    def require_member_access
      head :forbidden unless Membership::Access.allowed?(user: current_user)
    end

    def render_composer(composer, status: :ok)
      component = if turbo_frame_request?
        curation, comment, content = composer.values_at(:curation, :comment, :content)
        DiscussionComposer.new(routes: CurationDiscussionRoutes.new(curation:), comment:, content:, editing: true)
      else
        Views::Community::EditCurationComment.new(**composer)
      end
      render component, status:, content_type: Mime[:html]
    end
  end
end

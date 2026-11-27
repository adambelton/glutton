module Community
  module CurationCommentActions
    private

    def edit_curation_comment
      composer = Discussions::ManageCurationComment.load_for_edit(curation_id: post_id, comment_id:, community_user: current_user.community_user)
      render_curation_comment_editor(composer)
    end

    def update_curation_comment
      body = params[:body]
      raise ActionController::BadRequest unless body.nil? || body.is_a?(String)

      composer = Discussions::ManageCurationComment.edit(curation_id: post_id, comment_id:, community_user: current_user.community_user, body:)
      return render_curation_comment_editor(composer, status: :unprocessable_content) if composer.fetch(:content).errors.any?

      curation, comment = composer.values_at(:curation, :comment)
      if turbo_frame_request?
        return render Views::Community::DiscussionCommentEdited.new(routes: DiscussionRoutes.new(post: curation), comment:, can_reply: Membership::PostingAccess.allowed?(user: current_user)),
          content_type: Mime[:turbo_stream]
      end

      redirect_to community_post_path(curation, reply: comment.id, anchor: "comment-#{comment.id}"),
        notice: t("community.comment_editing.saved"), status: :see_other
    end

    def destroy_curation_comment
      removal = Discussions::ManageCurationComment.delete(curation_id: post_id, comment_id:, community_user: current_user.community_user)
      curation, film_id, selected_comment_id, nomination_visible = removal.values_at(:curation, :film_id, :selected_comment_id, :nomination_visible)
      if request.format.turbo_stream? && nomination_visible
        discussion = Discussions::CurationDiscussion.new(curation:, film_id:, selected_reply_id: selected_comment_id, expand_selected_branch: true)
        return render Views::Community::CurationFilmDiscussionUpdate.new(curation:, film_id:, discussion:,
          can_reply: Membership::PostingAccess.allowed?(user: current_user)), content_type: Mime[:turbo_stream]
      end

      unless nomination_visible
        return redirect_to community_post_path(curation), notice: t("community.comment_deletion.deleted"), status: :see_other
      end

      anchor = selected_comment_id.present? ? "comment-#{selected_comment_id}" : "nomination-#{film_id}"
      redirect_to community_post_path(curation, reply: selected_comment_id, anchor:),
        notice: t("community.comment_deletion.deleted"), status: :see_other
    end

    def render_curation_comment_editor(composer, status: :ok)
      component = if turbo_frame_request?
        curation, comment, content = composer.values_at(:curation, :comment, :content)
        DiscussionComposer.new(routes: DiscussionRoutes.new(post: curation), comment:, content:, editing: true)
      else
        Views::Community::EditCurationComment.new(**composer)
      end
      render component, status:, content_type: Mime[:html]
    end
  end
end

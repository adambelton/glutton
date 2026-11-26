module Community
  module DebriefCommentActions
    private

    def new_debrief_reply
      editor = Discussions::ManageFilmDebriefDiscussion.load_for_reply(post_id:, parent_id: comment_id, member: current_user)
      render_debrief_composer(**editor)
    end

    def publish_debrief_comment
      parent_id = comment_id if request.path_parameters.key?(:id)
      result = Discussions::ManageFilmDebriefDiscussion.publish(post_id:, parent_id:, member_id: current_user.id, body:)
      debrief, parent, content = result.values_at(:debrief, :parent, :content)
      if content.errors.any?
        return render_debrief_composer(debrief:, parent:, content:, status: :unprocessable_content) if parent.present?

        return render_root_error(debrief:, content:)
      end

      if turbo_frame_request? || request.format.turbo_stream?
        return render_discussion(debrief, selected_id: content.comment_id, focus_selected: true)
      end

      key = parent.present? ? "community.curation_replies.published" : "community.film_debriefs.comment_published"
      redirect_to DiscussionRoutes.new(post: debrief).post_path(content.comment), notice: t(key), status: :see_other
    end

    def edit_debrief_comment
      editor = Discussions::ManageFilmDebriefDiscussion.load_for_edit(post_id:, comment_id: comment_id, member: current_user)
      render_debrief_composer(**editor, editing: true)
    end

    def update_debrief_comment
      editor = Discussions::ManageFilmDebriefDiscussion.edit(post_id:, comment_id: comment_id, member_id: current_user.id, body:)
      debrief, comment, content = editor.values_at(:debrief, :comment, :content)
      return render_debrief_composer(**editor, editing: true, status: :unprocessable_content) if content.errors.any?

      routes = DiscussionRoutes.new(post: debrief)
      if turbo_frame_request? || request.format.turbo_stream?
        return render Views::Community::DiscussionCommentEdited.new(routes:, comment:, can_reply: true), content_type: Mime[:turbo_stream]
      end

      redirect_to routes.post_path(comment), notice: t("community.comment_editing.saved"), status: :see_other
    end

    def destroy_debrief_comment
      result = Discussions::ManageFilmDebriefDiscussion.delete(post_id:, comment_id: comment_id, member_id: current_user.id)
      debrief, selected_id = result.values_at(:debrief, :selected_id)
      return render_discussion(debrief, selected_id:) if request.format.turbo_stream?

      anchor = selected_id.present? ? "comment-#{selected_id}" : FilmDebriefDiscussion.section_id(debrief)
      redirect_to community_post_path(debrief, reply: selected_id, anchor:),
        notice: t("community.comment_deletion.deleted"), status: :see_other
    end

    def body
      value = params[:body]
      raise ActionController::BadRequest unless value.nil? || value.is_a?(String)

      value
    end

    def render_root_error(debrief:, content:)
      component = if turbo_frame_request?
        FilmDebriefDiscussion.root_composer(debrief:, content:)
      else
        Views::Community::FilmDebrief.new(debrief:, discussion: Discussions::Discussion.new(post: debrief), can_reply: true, draft: content)
      end
      render component, status: :unprocessable_content, content_type: Mime[:html]
    end

    def render_debrief_composer(debrief:, content:, parent: nil, comment: nil, editing: false, status: :ok)
      target = comment || parent
      routes = DiscussionRoutes.new(post: debrief)
      component = if turbo_frame_request?
        DiscussionComposer.new(routes:, comment: target, content:, editing:, avoid_spoilers: false)
      else
        Views::Community::DebriefCommentEditor.new(routes:, comment: target, content:, editing:)
      end
      render component, status:, content_type: Mime[:html]
    end

    def render_discussion(debrief, selected_id:, focus_selected: false)
      discussion = Discussions::Discussion.new(post: debrief, selected_reply_id: selected_id, expand_selected_branch: true, focus_selected:)
      can_reply = Membership::PostingAccess.allowed?(user: current_user)
      render Views::Community::FilmDebriefDiscussionUpdated.new(debrief:, discussion:, can_reply:), content_type: Mime[:turbo_stream]
    end
  end
end

module Community
  class FilmDebriefCommentsController < ApplicationController
    include FilmDebriefControllerAccess

    def new
      editor = Discussions::ManageFilmDebriefDiscussion.load_for_reply(film_id:, parent_id: discussion_id(params[:parent_id]), member: current_user)
      render_composer(**editor)
    end

    def create
      parent_id = discussion_id(params[:parent_id]) if params.key?(:parent_id)
      result = Discussions::ManageFilmDebriefDiscussion.publish(film_id:, parent_id:, member_id: current_user.id, body:)
      debrief, parent, content = result.values_at(:debrief, :parent, :content)
      if content.errors.any?
        return render_composer(debrief:, parent:, content:, status: :unprocessable_content) if parent.present?

        return render_root_error(debrief:, content:)
      end

      if turbo_frame_request? || request.format.turbo_stream?
        return render_discussion(debrief, selected_id: content.comment_id, focus_selected: true)
      end

      key = parent.present? ? "community.curation_replies.published" : "community.film_debriefs.comment_published"
      redirect_to DebriefDiscussionRoutes.new(debrief:).post_path(content.comment), notice: t(key), status: :see_other
    end

    def edit
      editor = Discussions::ManageFilmDebriefDiscussion.load_for_edit(film_id:, comment_id: discussion_id(params[:id]), member: current_user)
      render_composer(**editor, editing: true)
    end

    def update
      editor = Discussions::ManageFilmDebriefDiscussion.edit(film_id:, comment_id: discussion_id(params[:id]), member_id: current_user.id, body:)
      debrief, comment, content = editor.values_at(:debrief, :comment, :content)
      return render_composer(**editor, editing: true, status: :unprocessable_content) if content.errors.any?

      routes = DebriefDiscussionRoutes.new(debrief:)
      if turbo_frame_request? || request.format.turbo_stream?
        return render Views::Community::DiscussionCommentEdited.new(routes:, comment:, can_reply: true), content_type: Mime[:turbo_stream]
      end

      redirect_to routes.post_path(comment), notice: t("community.comment_editing.saved"), status: :see_other
    end

    def destroy
      result = Discussions::ManageFilmDebriefDiscussion.delete(film_id:, comment_id: discussion_id(params[:id]), member_id: current_user.id)
      debrief, selected_id = result.values_at(:debrief, :selected_id)
      return render_discussion(debrief, selected_id:) if request.format.turbo_stream?

      anchor = selected_id.present? ? "comment-#{selected_id}" : FilmDebriefDiscussion.section_id(debrief)
      redirect_to community_film_debrief_path(debrief.film_id, reply: selected_id, anchor:),
        notice: t("community.comment_deletion.deleted"), status: :see_other
    end

    private

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

    def render_composer(debrief:, content:, parent: nil, comment: nil, editing: false, status: :ok)
      target = comment || parent
      routes = DebriefDiscussionRoutes.new(debrief:)
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

module Community
  class CurationRepliesController < ApplicationController
    rescue_from Errors::PostingUnavailable, with: -> { head :forbidden }

    def new
      composer = Discussions::PublishCurationReply.load_for_reply(curation_id: params[:curation_id], comment_id: params[:comment_id], member: current_user)
      render_composer(composer)
    end

    def create
      body = params[:body]
      raise ActionController::BadRequest unless body.nil? || body.is_a?(String)

      composer = Discussions::PublishCurationReply.call(curation_id: params[:curation_id], comment_id: params[:comment_id],
        member_id: current_user.id, body:)
      reply = composer.fetch(:reply)
      if reply.errors.any?
        return render_composer(composer, status: :unprocessable_content)
      end

      if turbo_frame_request?
        film_id = Discussions::CurationDiscussion.film_id_for(composer.fetch(:parent))
        discussion = Discussions::CurationDiscussion.new(curation: composer.fetch(:curation), film_id:)
        return render Views::Community::CurationReplyPublished.new(**composer, film_id:, discussion:), content_type: Mime[:turbo_stream]
      end

      redirect_to community_curation_path(composer.fetch(:curation), reply: reply.comment_id, anchor: "comment-#{reply.comment_id}"),
        notice: t("community.curation_replies.published"), status: :see_other
    end

    private

    def render_composer(composer, status: :ok)
      component = if turbo_frame_request?
        curation, comment, content = composer.values_at(:curation, :parent, :reply)
        DiscussionComposer.new(routes: CurationDiscussionRoutes.new(curation:), comment:, content:)
      else
        Views::Community::NewCurationReply.new(**composer)
      end
      render component, status:, content_type: Mime[:html]
    end
  end
end

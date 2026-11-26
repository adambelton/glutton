module Community
  class PostCommentsController < ApplicationController
    include CurationCommentActions
    include CurationReplyActions
    include DebriefCommentActions

    before_action :load_post
    rescue_from Errors::MembershipRequired, Errors::PostingUnavailable, Errors::CommentChangeUnavailable, with: -> { head :forbidden }
    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

    def create
      run_comment_action(:create)
    end

    def new_reply
      run_comment_action(:new_reply)
    end

    def create_reply
      run_comment_action(:create_reply)
    end

    def edit
      run_comment_action(:edit)
    end

    def update
      run_comment_action(:update)
    end

    def destroy
      run_comment_action(:destroy)
    end

    private

    def run_comment_action(action_name)
      action = PostResponses.comment_action(post: @post, action_name:)
      return head :not_found unless action.present?

      send(action)
    end

    def load_post
      @post = Posts::ReadPost.call(id: post_id, viewer: current_user)
    end

    def post_id
      discussion_id(params[:post_id])
    end

    def comment_id
      discussion_id(params[:id])
    end

    def discussion_id(value)
      raise ActionController::BadRequest unless RecordId.valid?(value)

      value.to_i
    end
  end
end

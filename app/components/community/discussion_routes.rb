module Community
  class DiscussionRoutes
    include Rails.application.routes.url_helpers

    def initialize(post:, film_id: nil)
      @post, @film_id = post, film_id
    end

    def page_path(parent_id:, after:)
      discussion_community_post_path(@post, film_id: @film_id, parent_id:, after:)
    end

    def comment_path(comment)
      community_post_comment_path(@post, comment)
    end

    def edit_path(comment)
      edit_community_post_comment_path(@post, comment)
    end

    def reply_path(comment)
      reply_community_post_comment_path(@post, comment)
    end

    def new_reply_path(comment)
      new_reply_community_post_comment_path(@post, comment)
    end

    def new_report_path(comment)
      new_community_post_comment_report_path(@post, comment)
    end

    def post_path(comment)
      community_post_path(@post, reply: comment.id, anchor: "comment-#{comment.id}")
    end

    def root_form_path
      community_post_comments_path(@post)
    end
  end
end

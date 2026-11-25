module Community
  class DebriefDiscussionRoutes
    include Rails.application.routes.url_helpers

    def initialize(debrief:)
      @film_id = debrief.film_id
    end

    def page_path(parent_id:, after:)
      community_film_debrief_discussion_path(@film_id, parent_id:, after:)
    end

    def comment_path(comment)
      community_film_debrief_comment_path(@film_id, comment)
    end

    def edit_path(comment)
      edit_community_film_debrief_comment_path(@film_id, comment)
    end

    def reply_path(comment)
      community_film_debrief_comments_path(@film_id, parent_id: comment.id)
    end

    def new_reply_path(comment)
      new_community_film_debrief_comment_path(@film_id, parent_id: comment.id)
    end

    def post_path(comment)
      community_film_debrief_path(@film_id, reply: comment.id, anchor: "comment-#{comment.id}")
    end

    def root_form_path
      community_film_debrief_comments_path(@film_id)
    end
  end
end

module Community
  class CurationDiscussionRoutes
    include Rails.application.routes.url_helpers

    def initialize(curation:, film_id: nil)
      @curation, @film_id = curation, film_id
    end

    def page_path(parent_id:, after:)
      discussion_community_curation_path(@curation, film_id: @film_id, parent_id:, after:)
    end

    def comment_path(comment)
      community_curation_comment_path(@curation, comment)
    end

    def edit_path(comment)
      edit_community_curation_comment_path(@curation, comment)
    end

    def reply_path(comment)
      community_curation_comment_reply_path(@curation, comment)
    end

    def new_reply_path(comment)
      new_community_curation_comment_reply_path(@curation, comment)
    end

    def post_path(comment)
      community_curation_path(@curation, reply: comment.id, anchor: "comment-#{comment.id}")
    end
  end
end

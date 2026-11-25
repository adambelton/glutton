module Community
  class CurationCommentLoader < Shared::Base
    def initialize(curation:, film_id:, parent_id: nil, after: nil)
      @curation, @film_id, @parent_id, @after = curation, film_id, parent_id, after
    end

    def view_template
      div(class: "community-comment-loader", data: { community_film_comments_target: "loader",
        discussion_url: discussion_community_curation_path(@curation, film_id: @film_id, parent_id: @parent_id, after: @after),
        initial_page: (@after.nil? ? "true" : "false") }) do
        button(type: :button, class: "ui-link", data: { action: "community-film-comments#loadMore" }) do
          t("community.curation_replies.load_more")
        end
        p(hidden: true, role: "alert") { t("community.curation_replies.load_failed") }
      end
    end
  end
end

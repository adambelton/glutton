module Community
  class CurationComments < Shared::Base
    def initialize(curation:, film_id:, discussion:, can_reply:)
      @curation, @film_id, @discussion, @can_reply = curation, film_id, discussion, can_reply
    end

    def view_template
      div(id: "film-discussion-#{@film_id}") do
        discussion
      end
    end

    private

    def discussion
      count = @discussion.count_for_film(@film_id)
      label = t("community.curations.comments", count:)
      if count.zero?
        p(class: "muted community-comment-count") { label }
      else
        open = @discussion.reveal?(@film_id)
        details(class: "community-film-comments", open:,
          data: { community_film_comments_target: "film", action: "toggle->community-film-comments#toggle" }) do
          summary(id: "film-comment-count-#{@film_id}") { label }
          if open
            render CurationCommentPage.new(curation: @curation, film_id: @film_id, parent_id: nil, discussion: @discussion, can_reply: @can_reply)
          else
            render CurationCommentLoader.new(curation: @curation, film_id: @film_id)
          end
        end
      end
    end
  end
end

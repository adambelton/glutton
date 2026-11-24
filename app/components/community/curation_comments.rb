module Community
  class CurationComments < Shared::Base
    def initialize(curation:, film_id:, discussion:, can_reply:)
      @curation, @film_id, @discussion, @can_reply = curation, film_id, discussion, can_reply
      @roots = discussion.roots(film_id)
    end

    def view_template
      div(id: "film-discussion-#{@film_id}") do
        discussion
      end
    end

    private

    def discussion
      label = t("community.curations.comments", count: @discussion.count(@roots))
      if @roots.empty?
        p(class: "muted community-comment-count") { label }
      else
        details(class: "community-film-comments", open: @discussion.reveal?(@roots),
          data: { community_film_comments_target: "film", action: "toggle->community-film-comments#updateControls" }) do
          summary(id: "film-comment-count-#{@film_id}") { label }
          @roots.each do |root|
            render CurationCommentThread.new(curation: @curation, comment: root, discussion: @discussion, can_reply: @can_reply)
          end
        end
      end
    end
  end
end

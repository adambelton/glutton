module Community
  class CurationComments < Shared::Base
    def initialize(curation:, film:, discussion:, endorsements:, can_reply:)
      @curation, @film, @discussion, @can_reply = curation, film, discussion, can_reply
      @roots = discussion.roots(endorsements)
    end

    def view_template
      label = t("community.curations.comments", count: @discussion.count(@roots))
      if @roots.empty?
        p(class: "muted community-comment-count") { label }
      else
        details(class: "community-film-comments", open: @discussion.reveal?(@roots),
          data: { community_film_comments_target: "film", action: "toggle->community-film-comments#updateControls" }) do
          summary(id: "film-comment-count-#{@film.id}") { label }
          @roots.each do |root|
            render CurationCommentThread.new(curation: @curation, comment: root, discussion: @discussion, can_reply: @can_reply)
          end
        end
      end
    end
  end
end

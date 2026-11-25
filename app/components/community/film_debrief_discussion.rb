module Community
  class FilmDebriefDiscussion < Shared::Base
    def self.section_id(debrief)
      "film-debrief-#{debrief.id}-discussion"
    end

    def self.root_composer(debrief:, content:)
      routes = DebriefDiscussionRoutes.new(debrief:)
      DiscussionCommentForm.new(content:, frame_id: "film-debrief-#{debrief.id}-composer", path: routes.root_form_path, mode: :root, inline: true)
    end

    def initialize(debrief:, discussion:, can_reply:, draft: nil)
      @debrief, @discussion, @can_reply, @draft = debrief, discussion, can_reply, draft
    end

    def view_template
      heading_id = "film-debrief-#{@debrief.id}-discussion-heading"
      section(id: self.class.section_id(@debrief), class: "community-debrief-discussion", aria: { labelledby: heading_id },
        data: { controller: "community-film-comments" }) do
        h2(id: heading_id) { t("community.film_debriefs.discussion") }
        if @can_reply
          render self.class.root_composer(debrief: @debrief, content: @draft || CommentContent.new)
        end
        div(class: "community-debrief-threads") do
          render DiscussionCommentPage.new(routes: DebriefDiscussionRoutes.new(debrief: @debrief), parent_id: nil,
            discussion: @discussion, can_reply: @can_reply)
        end
      end
    end
  end
end

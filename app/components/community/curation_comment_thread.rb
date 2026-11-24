module Community
  class CurationCommentThread < Shared::Base
    def initialize(curation:, comment:, discussion:, can_reply:, newly_published: false)
      @curation, @comment, @discussion, @can_reply = curation, comment, discussion, can_reply
      @newly_published = newly_published
    end

    def view_template
      div(class: "community-comment-thread", id: "comment-thread-#{@comment.id}") do
        render CurationComment.new(curation: @curation, comment: @comment, can_reply: @can_reply, newly_published: @newly_published)
        if @can_reply && @comment.content.present?
          tag(:"turbo-frame", id: CurationCommentComposer.frame_id(@comment), class: "community-comment-editor-branch")
        end
        reply_branch
      end
    end

    private

    def reply_branch
      replies = @discussion.replies(@comment)
      details(id: "replies-#{@comment.id}", class: "community-comment-replies", hidden: replies.empty?,
        open: @discussion.expanded?(@comment),
        data: { community_film_comments_target: "branch", action: "toggle->community-film-comments#updateControls" }) do
        summary(id: "reply-count-#{@comment.id}") { t("community.curation_replies.replies", count: replies.size) }
        replies.each do |reply|
          render self.class.new(curation: @curation, comment: reply, discussion: @discussion, can_reply: @can_reply)
        end
      end
    end
  end
end

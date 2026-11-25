module Community
  class CurationCommentThread < Shared::Base
    def initialize(curation:, film_id:, comment:, discussion:, can_reply:, reply_count:, newly_published: false)
      @curation, @film_id, @comment, @discussion, @can_reply = curation, film_id, comment, discussion, can_reply
      @reply_count = reply_count
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
      open = @reply_count.positive? && @discussion.expanded?(@comment)
      details(id: "replies-#{@comment.id}", class: "community-comment-replies", hidden: @reply_count.zero?, open:,
        data: { community_film_comments_target: "branch", action: "toggle->community-film-comments#toggle" }) do
        summary(id: "reply-count-#{@comment.id}") { t("community.curation_replies.replies", count: @reply_count) }
        if open
          render CurationCommentPage.new(curation: @curation, film_id: @film_id, parent_id: @comment.id, discussion: @discussion, can_reply: @can_reply)
        elsif @reply_count.positive?
          render CurationCommentLoader.new(curation: @curation, film_id: @film_id, parent_id: @comment.id)
        end
      end
    end
  end
end

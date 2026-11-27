module Community
  class DiscussionCommentThread < Shared::Base
    def initialize(routes:, film_id: nil, comment:, discussion:, can_reply:, reply_count:, newly_published: false)
      @routes, @film_id, @comment, @discussion, @can_reply = routes, film_id, comment, discussion, can_reply
      @reply_count = reply_count
      @newly_published = newly_published
    end

    def view_template
      content = @comment.content
      hidden = Membership::MemberVisibility.hidden?(viewer: current_user, blockable: content)
      can_reply = @can_reply && content.present? && !hidden
      div(class: "community-comment-thread", id: "comment-thread-#{@comment.id}") do
        render DiscussionComment.new(routes: @routes, comment: @comment, can_reply:, hidden:,
          newly_published: @newly_published || @discussion.focus?(@comment))
        if can_reply
          tag(:"turbo-frame", id: DiscussionComposer.frame_id(@comment), class: "community-comment-editor-branch")
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
          render DiscussionCommentPage.new(routes: @routes, film_id: @film_id, parent_id: @comment.id, discussion: @discussion, can_reply: @can_reply)
        elsif @reply_count.positive?
          render DiscussionCommentLoader.new(routes: @routes, parent_id: @comment.id)
        end
      end
    end
  end
end

module Community
  class CurationCommentThread < Shared::Base
    include Phlex::Rails::Helpers::ImagePath

    def initialize(curation:, comment:, discussion:, can_reply:, newly_published: false)
      @curation, @comment, @discussion, @can_reply = curation, comment, discussion, can_reply
      @newly_published = newly_published
    end

    def view_template
      div(class: "community-comment-thread", id: "comment-thread-#{@comment.id}") do
        comment_article
        reply_branch
      end
    end

    private

    def comment_article
      data = { community_film_comments_target: "newReply" } if @newly_published
      article(class: "community-comment", id: "comment-#{@comment.id}", tabindex: ("-1" if @newly_published), data:) do
        if @comment.content.present?
          comment_body
        else
          p(class: "muted") { t("community.curation_replies.removed") }
        end
      end
    end

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

    def comment_body
      content = @comment.content
      author = content.author
      if author.community_avatar_preset.present?
        img(class: "community-comment-avatar", src: image_path("community-avatars/#{author.community_avatar_preset}.png"),
          alt: "", width: 32, height: 32, loading: "lazy")
      end
      div(class: "community-comment-content") do
        strong { author.community_username.presence || t("community.curations.member") }
        p(class: "community-curation-prompt") { content.body }
        div(class: "community-comment-actions") do
          if @can_reply
            text_link(t("community.curations.reply"), new_community_curation_comment_reply_path(@curation, @comment),
              data: { turbo_frame: CurationReplyComposer.frame_id(@comment) })
          end
          button(type: :button, disabled: true) { t("community.curations.report") }
        end
        tag(:"turbo-frame", id: CurationReplyComposer.frame_id(@comment)) if @can_reply
      end
    end
  end
end

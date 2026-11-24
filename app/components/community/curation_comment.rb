module Community
  class CurationComment < Shared::Base
    def initialize(curation:, comment:, can_reply:, newly_published: false)
      @curation, @comment, @can_reply, @newly_published = curation, comment, can_reply, newly_published
    end

    def view_template
      data = { community_film_comments_target: "newReply" } if @newly_published
      article(class: "community-comment", id: "comment-#{@comment.id}", tabindex: ("-1" if @newly_published), data:) do
        if @comment.content.present?
          comment_body
        else
          p(class: "muted") { t("community.curation_replies.removed") }
        end
      end
    end

    private

    def comment_body
      content = @comment.content
      author = content.author
      render CommentAvatar.new(member: author)
      can_edit = @comment.can_edit_inline?(member: current_user)
      div(class: "community-comment-content") do
        strong { author.community_username.presence || t("community.curations.member") }
        span(class: "community-curation-prompt") { content.body }
        div(class: "community-comment-actions") do
          if @can_reply
            a(href: new_community_curation_comment_reply_path(@curation, @comment),
              data: { turbo_frame: CurationCommentComposer.frame_id(@comment), comment_composer_trigger: "reply" }) { t("community.curations.reply") }
          end
          if can_edit
            a(href: edit_community_curation_comment_path(@curation, @comment),
              data: { turbo_frame: CurationCommentComposer.frame_id(@comment, editing: true), comment_composer_trigger: "edit" }) { t("community.comment_editing.edit") }
          end
          delete_action if @comment.can_delete?(member: current_user)
          button(type: :button, disabled: true) { t("community.curations.report") }
        end
        if can_edit
          tag(:"turbo-frame", id: CurationCommentComposer.frame_id(@comment, editing: true), class: "community-comment-edit-frame")
        end
      end
    end

    def delete_action
      render Shared::ConfirmationDialog.new(id: "delete-comment-#{@comment.id}", action_label: t("community.comment_deletion.delete"),
        title: t("community.comment_deletion.confirm_title"), description: t("community.comment_deletion.confirm_description"),
        cancel_label: t("community.curations.cancel"), url: community_curation_comment_path(@curation, @comment), trigger_variant: :ghost)
    end
  end
end

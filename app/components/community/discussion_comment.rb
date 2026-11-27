module Community
  class DiscussionComment < Shared::Base
    def initialize(routes:, comment:, can_reply:, newly_published: false)
      @routes, @comment, @can_reply, @newly_published = routes, comment, can_reply, newly_published
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
      community_user = content.community_user
      render MemberAvatar.new(community_user:)
      can_edit = @comment.can_edit_inline?(community_user: current_user.community_user)
      can_delete = @comment.can_delete?(community_user: current_user.community_user)
      div(class: "community-comment-content") do
        div(class: "community-comment-author flex flex-wrap items-baseline gap-x-2") do
          strong { community_user.community_username.presence || t("community.curations.member") }
          span(class: "muted community-comment-edited") { t("community.comment_editing.edited") } if content.edited_at.present?
        end
        span(class: "community-curation-prompt") { content.body }
        comment_actions(can_edit:, can_delete:)
        if can_edit
          tag(:"turbo-frame", id: DiscussionComposer.frame_id(@comment, editing: true), class: "community-comment-edit-frame")
        end
      end
    end

    def comment_actions(can_edit:, can_delete:)
      div(class: "community-comment-actions") do
        if @can_reply
          a(href: @routes.new_reply_path(@comment),
            data: { turbo_frame: DiscussionComposer.frame_id(@comment), comment_composer_trigger: "reply" }) { t("community.curations.reply") }
        end
        if can_edit
          a(href: @routes.edit_path(@comment),
            data: { turbo_frame: DiscussionComposer.frame_id(@comment, editing: true), comment_composer_trigger: "edit" }) { t("community.comment_editing.edit") }
        end
        delete_action if can_delete
        a(href: @routes.new_report_path(@comment), data: { turbo_frame: "_top" }) { t("community.reports.action") }
      end
    end

    def delete_action
      render Shared::ConfirmationDialog.new(id: "delete-comment-#{@comment.id}", action_label: t("community.comment_deletion.delete"),
        title: t("community.comment_deletion.confirm_title"), description: t("community.comment_deletion.confirm_description"),
        cancel_label: t("community.curations.cancel"), url: @routes.comment_path(@comment), trigger_variant: :plain)
    end
  end
end

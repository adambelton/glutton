module Community
  class CurationCommentComposer < Shared::Base
    def self.frame_id(comment, editing: false)
      "#{editing ? 'edit-comment' : 'comment'}-composer-#{comment.id}"
    end

    def initialize(curation:, comment:, content:, inline: true, editing: false)
      @curation, @comment, @content = curation, comment, content
      @inline, @editing = inline, editing
    end

    def view_template
      tag(:"turbo-frame", id: frame_id) do
        if @inline && !@editing
          div(class: "community-comment-thread") do
            div(class: "community-comment") do
              render CommentAvatar.new(member: current_user)
              div(class: "community-comment-content") { editor_form }
            end
          end
        else
          editor_form
        end
      end
    end

    private

    def editor_form
      form_with(url: form_path, method: (@editing ? :patch : :post), class: [ "community-comment-composer", ("community-comment-editor" if inline_edit?) ],
        data: { controller: "community-comment-composer", turbo_frame: ("_top" unless @inline),
                comment_composer_trigger: (@editing ? "edit" : "reply") }) do
        errors(@content.errors.full_messages)
        input_id = "#{frame_id}-body"
        guidance_id = "#{frame_id}-guidance" unless inline_edit?
        label_text = t(@editing ? "community.comment_editing.body" : "community.curation_replies.body")
        label(for: input_id, class: "sr-only") { label_text }
        textarea(id: input_id, name: "body", class: "ui-input", rows: 1, placeholder: label_text,
          maxlength: character_limit, required: true, aria: { describedby: guidance_id },
          data: { community_comment_composer_target: "body" }) { @content.body }
        if guidance_id.present?
          p(id: guidance_id, class: "muted") do
            if character_limit.present?
              t("community.curation_replies.guidance", count: character_limit)
            else
              t("community.comment_editing.guidance")
            end
          end
        end
        div(class: (inline_edit? ? "community-comment-actions" : "ui-actions")) do
          a(href: community_curation_path(@curation, reply: @comment.id, anchor: "comment-#{@comment.id}"),
            class: ("ui-link" unless inline_edit?), data: { turbo_frame: "_top", action: "community-comment-composer#cancel" }) do
            t("community.curations.cancel")
          end
          if inline_edit?
            button(type: :submit) { t("community.comment_editing.save") }
          else
            render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button") do
              t(@editing ? "community.comment_editing.save" : "community.curation_replies.publish")
            end
          end
        end
      end
    end

    def frame_id
      self.class.frame_id(@comment, editing: @editing)
    end

    def inline_edit?
      @inline && @editing
    end

    def form_path
      @editing ? community_curation_comment_path(@curation, @comment) : community_curation_comment_reply_path(@curation, @comment)
    end

    def character_limit
      CommentContent::REPLY_LIMIT if !@editing || @comment.parent_id.present?
    end
  end
end

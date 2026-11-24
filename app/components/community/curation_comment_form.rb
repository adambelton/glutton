module Community
  class CurationCommentForm < Shared::Base
    COPY = {
      reply: %w[curation_replies.body curation_replies.publish comment_editing.guidance],
      edit: %w[comment_editing.body comment_editing.save comment_editing.guidance]
    }.freeze

    def initialize(content:, frame_id:, path:, cancel_path:, mode:, inline:, character_limit: nil)
      @content, @frame_id, @path, @cancel_path = content, frame_id, path, cancel_path
      @mode, @inline, @character_limit = mode, inline, character_limit
    end

    def view_template
      tag(:"turbo-frame", id: @frame_id) do
        if @inline && @mode != :edit
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
      label, submit_label, guidance = COPY.fetch(@mode)
      form_with(url: @path, method: (@mode == :edit ? :patch : :post),
        class: [ "community-comment-composer", ("community-comment-editor" if inline_edit?) ],
        data: { controller: "community-comment-composer", turbo_frame: ("_top" unless @inline), comment_composer_trigger: @mode.to_s }) do
        errors(@content.errors.full_messages)
        input_id = "#{@frame_id}-body"
        guidance_id = "#{@frame_id}-guidance" unless inline_edit?
        label_text = t("community.#{label}")
        label(for: input_id, class: "sr-only") { label_text }
        textarea(id: input_id, name: "body", class: "ui-input", rows: 1, placeholder: label_text,
          maxlength: @character_limit, required: true, aria: { describedby: guidance_id },
          data: { community_comment_composer_target: "body" }) { @content.body }
        if guidance_id.present?
          p(id: guidance_id, class: "muted") do
            if @character_limit.present?
              t("community.curation_replies.guidance", count: @character_limit)
            else
              t("community.#{guidance}")
            end
          end
        end
        editor_actions(t("community.#{submit_label}"))
      end
    end

    def editor_actions(submit_label)
      div(class: "ui-actions ui-actions-fixed justify-end") do
        render RubyUI::Link.new(href: @cancel_path, variant: :ghost, class: "ui-action-button",
          data: { turbo_frame: "_top", action: "community-comment-composer#cancel" }) do
          t("community.curations.cancel")
        end
        render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button") { submit_label }
      end
    end

    def inline_edit?
      @inline && @mode == :edit
    end
  end
end

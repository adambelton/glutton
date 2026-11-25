module Community
  class DiscussionCommentForm < Shared::Base
    COPY = {
      root: %w[comment_editing.body film_debriefs.publish_comment],
      reply: %w[curation_replies.body curation_replies.publish],
      edit: %w[comment_editing.body comment_editing.save]
    }.freeze

    def initialize(content:, frame_id:, path:, mode:, inline:, cancel_path: nil, avoid_spoilers: false)
      @content, @frame_id, @path, @cancel_path = content, frame_id, path, cancel_path
      @mode, @inline, @avoid_spoilers = mode, inline, avoid_spoilers
    end

    def view_template
      tag(:"turbo-frame", id: @frame_id) do
        if @inline && @mode != :edit
          div(class: "community-comment-thread") do
            div(class: "community-comment") do
              render MemberAvatar.new(member: current_user)
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
      label, submit_label = COPY.fetch(@mode)
      form_with(url: @path, method: (@mode == :edit ? :patch : :post),
        class: [ "community-comment-composer", ("community-comment-editor" if inline_edit?) ],
        data: editor_form_data) do
        errors(@content.errors.full_messages)
        input_id = "#{@frame_id}-body"
        guidance_id = "#{@frame_id}-guidance"
        label_text = t("community.#{label}")
        label(for: input_id, class: "sr-only") { label_text }
        textarea(id: input_id, name: "body", class: "ui-input", rows: 1, placeholder: label_text,
          maxlength: CommentContent::BODY_LIMIT, required: true, aria: { describedby: guidance_id },
          data: { community_comment_composer_target: "body" }) { @content.body }
        p(id: guidance_id, class: "muted") do
          key = @avoid_spoilers && !inline_edit? ? "community.curation_replies.guidance" : "community.comment_limit"
          t(key, count: CommentContent::BODY_LIMIT)
        end
        editor_actions(t("community.#{submit_label}"))
      end
    end

    def editor_form_data
      return {} if @mode == :root

      data = { controller: "community-comment-composer", turbo_frame: ("_top" unless @inline), comment_composer_trigger: @mode.to_s }
      return data unless @mode == :edit

      track_form_changes(baseline: { body: @content.attribute_in_database(:body) }, **data)
    end

    def editor_actions(submit_label)
      div(class: [ "ui-actions justify-end", (@cancel_path.present? ? "ui-actions-fixed" : "community-comment-publish-actions") ]) do
        if @cancel_path.present?
          render RubyUI::Link.new(href: @cancel_path, variant: :ghost, class: "ui-action-button",
            data: { turbo_frame: "_top", action: "community-comment-composer#cancel" }) do
            t("community.curations.cancel")
          end
        end
        render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button", disabled: (@mode == :edit && !@content.will_save_change_to_body?),
          data: ({ unchanged_form_target: "save" } if @mode == :edit)) { submit_label }
      end
    end

    def inline_edit?
      @inline && @mode == :edit
    end
  end
end

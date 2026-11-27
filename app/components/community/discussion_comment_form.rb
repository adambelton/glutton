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
        if @inline && @mode == :reply
          div(class: "community-comment-thread") do
            comment_box { editor_form }
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
        class: [ "community-comment-composer", ("community-comment-editor" if inline_edit?),
          ("community-debrief-composer" if @mode == :root) ],
        data: editor_form_data) do
        if @mode == :root
          comment_box { editor_fields(label) }
        else
          editor_fields(label)
        end
        editor_actions(t("community.#{submit_label}"))
      end
    end

    def comment_box(&block)
      div(class: "community-comment community-comment-composer-card") do
        render MemberAvatar.new(community_user: current_user.community_user)
        div(class: "community-comment-content", &block)
      end
    end

    def editor_fields(label)
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
    end

    def editor_form_data
      return form_validation if @mode == :root

      data = { controller: "community-comment-composer", turbo_frame: ("_top" unless @inline), comment_composer_trigger: @mode.to_s }
      return form_validation(**data) unless @mode == :edit

      track_form_changes(baseline: { body: @content.attribute_in_database(:body) }, **data)
    end

    def editor_actions(submit_label)
      if @cancel_path.present?
        render Shared::ActionRow.new(full_width: !@inline, full_width_on_mobile: @inline) do
          render RubyUI::Link.new(href: @cancel_path, variant: :ghost, class: "ui-action-button",
            data: { turbo_frame: "_top", action: "community-comment-composer#cancel" }) { t("community.curations.cancel") }
          validated_submit(submit_label, class_name: "ui-action-button")
        end
      else
        div(class: "ui-actions justify-end community-comment-publish-actions") do
          validated_submit(submit_label, class_name: "ui-action-button")
        end
      end
    end

    def inline_edit?
      @inline && @mode == :edit
    end
  end
end

module Community
  class CurationReplyComposer < Shared::Base
    def self.frame_id(comment)
      "reply-composer-#{comment.id}"
    end

    def initialize(curation:, parent:, reply:, inline: true)
      @curation, @parent, @reply = curation, parent, reply
      @inline = inline
    end

    def view_template
      tag(:"turbo-frame", id: self.class.frame_id(@parent)) do
        form_with(url: community_curation_comment_reply_path(@curation, @parent), class: "community-reply-composer",
          data: { controller: "community-reply-composer", turbo_frame: ("_top" unless @inline) }) do
          errors(@reply.errors.full_messages)
          input_id = "reply-body-#{@parent.id}"
          guidance_id = "reply-guidance-#{@parent.id}"
          label(for: input_id, class: "sr-only") { t("community.curation_replies.body") }
          textarea(id: input_id, name: "body", class: "ui-input", rows: 1, placeholder: t("community.curation_replies.body"),
            maxlength: CommentContent::REPLY_LIMIT, required: true, aria: { describedby: guidance_id },
            data: { community_reply_composer_target: "body" }) { @reply.body }
          p(id: guidance_id, class: "muted") { t("community.curation_replies.guidance", count: CommentContent::REPLY_LIMIT) }
          div(class: "ui-actions") do
            render RubyUI::Link.new(href: community_curation_path(@curation, reply: @parent.id, anchor: "comment-#{@parent.id}"),
              variant: :ghost, class: "ui-action-button", data: { turbo_frame: "_top", action: "community-reply-composer#cancel" }) do
              t("community.curations.cancel")
            end
            render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button") { t("community.curation_replies.publish") }
          end
        end
      end
    end
  end
end

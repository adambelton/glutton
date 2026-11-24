module Views
  module Community
    class NewCurationReply < ::Views::Base
      def initialize(curation:, parent:, reply:)
        @curation, @parent, @reply = curation, parent, reply
      end

      def view_template
        page(title: t("community.curation_replies.title"), narrow: true,
          back_to: community_curation_path(@curation, reply: @parent.id, anchor: "comment-#{@parent.id}"),
          back_label: t("community.curations.back_to_curation")) do
          blockquote(class: "community-curation-prompt") { @parent.content.body }
          render ::Community::CurationCommentComposer.new(curation: @curation, comment: @parent, content: @reply, inline: false)
        end
      end
    end
  end
end

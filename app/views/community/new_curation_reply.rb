module Views
  module Community
    class NewCurationReply < ::Views::Base
      def initialize(curation:, parent:, reply:)
        @curation, @parent, @reply = curation, parent, reply
      end

      def view_template
        page(title: t("community.curation_replies.title"), narrow: true) do
          blockquote(class: "community-curation-prompt") { @parent.content.body }
          render ::Community::DiscussionComposer.new(routes: ::Community::DiscussionRoutes.new(post: @curation), comment: @parent, content: @reply, inline: false)
        end
      end
    end
  end
end

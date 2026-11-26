module Views
  module Community
    class EditCurationComment < ::Views::Base
      def initialize(curation:, comment:, content:)
        @curation, @comment, @content = curation, comment, content
      end

      def view_template
        page(title: t("community.comment_editing.title"), narrow: true,
          back_to: community_post_path(@curation, reply: @comment.id, anchor: "comment-#{@comment.id}"),
          back_label: t("community.curations.back_to_curation")) do
          render ::Community::DiscussionComposer.new(routes: ::Community::DiscussionRoutes.new(post: @curation), comment: @comment, content: @content, editing: true, inline: false)
        end
      end
    end
  end
end

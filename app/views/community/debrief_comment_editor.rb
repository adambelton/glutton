module Views
  module Community
    class DebriefCommentEditor < ::Views::Base
      def initialize(routes:, comment:, content:, editing:)
        @routes, @comment, @content, @editing = routes, comment, content, editing
      end

      def view_template
        page(title: t(@editing ? "community.comment_editing.title" : "community.curation_replies.title"), narrow: true) do
          unless @editing
            blockquote(class: "community-curation-prompt") { @comment.content.body }
          end
          render ::Community::DiscussionComposer.new(routes: @routes, comment: @comment, content: @content,
            editing: @editing, inline: false, avoid_spoilers: false)
        end
      end
    end
  end
end

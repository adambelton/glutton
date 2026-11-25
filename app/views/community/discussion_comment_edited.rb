module Views
  module Community
    class DiscussionCommentEdited < Shared::Base
      def initialize(routes:, comment:, can_reply:)
        @routes, @comment, @can_reply = routes, comment, can_reply
      end

      def view_template
        tag(:"turbo-stream", action: "replace", target: "comment-#{@comment.id}") do
          tag(:template) do
            render ::Community::DiscussionComment.new(routes: @routes, comment: @comment, can_reply: @can_reply)
          end
        end
      end
    end
  end
end

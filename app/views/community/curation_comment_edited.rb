module Views
  module Community
    class CurationCommentEdited < Shared::Base
      def initialize(curation:, comment:, can_reply:)
        @curation, @comment, @can_reply = curation, comment, can_reply
      end

      def view_template
        tag(:"turbo-stream", action: "replace", target: "comment-#{@comment.id}") do
          tag(:template) do
            render ::Community::CurationComment.new(curation: @curation, comment: @comment, can_reply: @can_reply)
          end
        end
      end
    end
  end
end

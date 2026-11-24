module Views
  module Community
    class CurationReplyPublished < Shared::Base
      def initialize(curation:, parent:, reply:, discussion:)
        @curation, @parent, @reply = curation, parent, reply
        @discussion = discussion
      end

      def view_template
        film_id = @parent.discussion_film_id

        stream("update", ::Community::CurationCommentComposer.frame_id(@parent))
        stream("update", "film-comment-count-#{film_id}") do
          plain t("community.curations.comments", count: @discussion.count_for_film(film_id))
        end
        stream("update", "reply-count-#{@parent.id}") do
          plain t("community.curation_replies.replies", count: @discussion.replies(@parent).size)
        end
        stream("append", "replies-#{@parent.id}") do
          render ::Community::CurationCommentThread.new(curation: @curation, comment: @reply.comment, discussion: @discussion,
            can_reply: true, newly_published: true)
        end
      end

      private

      def stream(action, target, &)
        tag(:"turbo-stream", action:, target:) { tag(:template, &) }
      end
    end
  end
end

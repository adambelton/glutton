module Views
  module Community
    class CurationReplyPublished < Shared::Base
      def initialize(curation:, parent:, reply:, film_id:, discussion:)
        @curation, @parent, @reply = curation, parent, reply
        @discussion = discussion
        @film_id = film_id
      end

      def view_template
        stream("update", ::Community::DiscussionComposer.frame_id(@parent))
        stream("update", "film-comment-count-#{@film_id}") do
          plain t("community.curations.comments", count: @discussion.count_for_film(@film_id))
        end
        stream("update", "reply-count-#{@parent.id}") do
          plain t("community.curation_replies.replies", count: @discussion.reply_counts([ @parent.id ]).fetch(@parent.id, 0))
        end
        stream("append", "replies-#{@parent.id}") do
          render ::Community::DiscussionCommentThread.new(routes: ::Community::CurationDiscussionRoutes.new(curation: @curation, film_id: @film_id), film_id: @film_id, comment: @reply.comment, discussion: @discussion,
            can_reply: true, reply_count: 0, newly_published: true)
        end
      end

      private

      def stream(action, target, &)
        tag(:"turbo-stream", action:, target:) { tag(:template, &) }
      end
    end
  end
end

module Community
  class CurationCommentPage < Shared::Base
    def initialize(curation:, film_id:, parent_id:, discussion:, can_reply:, after: nil)
      @curation, @film_id, @parent_id, @discussion, @can_reply, @after = curation, film_id, parent_id, discussion, can_reply, after
    end

    def view_template
      page = @discussion.page(film_id: @film_id, parent_id: @parent_id, after: @after)
      reply_counts = @discussion.reply_counts(page.comments.map(&:id))
      page.comments.each do |comment|
        if page.next_cursor.present? && comment.id > page.next_cursor
          loader(after: page.next_cursor)
          render_thread(comment, reply_counts)
          return
        end
        render_thread(comment, reply_counts)
      end
      loader(after: page.next_cursor) if page.next_cursor.present?
    end

    private

    def render_thread(comment, reply_counts)
      render CurationCommentThread.new(curation: @curation, film_id: @film_id, comment:, discussion: @discussion, can_reply: @can_reply,
        reply_count: reply_counts.fetch(comment.id, 0))
    end

    def loader(after:)
      render CurationCommentLoader.new(curation: @curation, film_id: @film_id, parent_id: @parent_id, after:)
    end
  end
end

module Community
  class DiscussionComposer < Shared::Base
    def self.frame_id(comment, editing: false)
      "#{editing ? 'edit-comment' : 'comment'}-composer-#{comment.id}"
    end

    def initialize(routes:, comment:, content:, inline: true, editing: false, avoid_spoilers: true)
      @routes, @comment, @content = routes, comment, content
      @inline, @editing = inline, editing
      @avoid_spoilers = avoid_spoilers
    end

    def view_template
      render DiscussionCommentForm.new(content: @content, frame_id: self.class.frame_id(@comment, editing: @editing),
        path: form_path, cancel_path: @routes.post_path(@comment),
        mode: (@editing ? :edit : :reply), inline: @inline, avoid_spoilers: @avoid_spoilers)
    end
    private

    def form_path
      @editing ? @routes.comment_path(@comment) : @routes.reply_path(@comment)
    end
  end
end

module Community
  class CurationCommentComposer < Shared::Base
    def self.frame_id(comment, editing: false)
      "#{editing ? 'edit-comment' : 'comment'}-composer-#{comment.id}"
    end

    def initialize(curation:, comment:, content:, inline: true, editing: false)
      @curation, @comment, @content = curation, comment, content
      @inline, @editing = inline, editing
    end

    def view_template
      render CurationCommentForm.new(content: @content, frame_id: self.class.frame_id(@comment, editing: @editing),
        path: form_path, cancel_path: community_curation_path(@curation, reply: @comment.id, anchor: "comment-#{@comment.id}"),
        mode: (@editing ? :edit : :reply), inline: @inline, character_limit:)
    end

    private

    def form_path
      @editing ? community_curation_comment_path(@curation, @comment) : community_curation_comment_reply_path(@curation, @comment)
    end

    def character_limit
      CommentContent::REPLY_LIMIT if !@editing || @comment.parent_id.present?
    end
  end
end

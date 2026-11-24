module Community
  class ManageCurationComment
    def self.load_for_edit(curation_id:, comment_id:, member:)
      curation = PostCommunityCuration.find(curation_id)
      comment = authored_comment(curation:, comment_id:)
      raise Errors::CommentChangeUnavailable unless comment.can_edit_inline?(member:)

      { curation:, comment:, content: comment.content }
    end

    def self.edit(curation_id:, comment_id:, member_id:, body:)
      with_comment(curation_id:, comment_id:, member_id:) do |curation, comment, member|
        content = comment.edit_body(member:, body:)
        { curation:, comment:, content: }
      end
    end

    def self.delete(curation_id:, comment_id:, member_id:)
      with_comment(curation_id:, comment_id:, member_id:) do |curation, comment, member|
        film_id = comment.discussion_film_id
        comment.delete_comment!(member:)
        selected_comment_id = comment.destroyed? ? comment.parent_id : comment.id
        nomination_visible = curation.visible_film_endorsements.exists?(film_id:)
        { curation:, film_id:, selected_comment_id:, nomination_visible: }
      end
    end

    def self.with_comment(curation_id:, comment_id:, member_id:)
      PostCommunityCuration.transaction do
        member = Identity::UserRegistered.lock.find_by(id: member_id)
        raise Errors::CommentChangeUnavailable unless member.present?

        curation = PostCommunityCuration.lock.find(curation_id)
        comment = authored_comment(curation:, comment_id:)
        yield curation, comment, member
      end
    end

    def self.authored_comment(curation:, comment_id:)
      curation.comments.joins(:content).preload(:content).find(comment_id)
    end

    private_class_method :with_comment, :authored_comment
  end
end

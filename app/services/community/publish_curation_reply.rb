module Community
  class PublishCurationReply
    def self.load_for_reply(curation_id:, comment_id:, member:)
      raise Errors::PostingUnavailable unless PostingAccess.allowed?(user: member)

      curation = PostCommunityCuration.find(curation_id)
      parent = find_parent(curation:, comment_id:)
      { curation:, parent:, reply: CommentContent.new }
    end

    def self.call(curation_id:, comment_id:, member_id:, body:)
      PostCommunityCuration.transaction do
        member = Identity::UserRegistered.lock.find_by(id: member_id)
        raise Errors::PostingUnavailable unless member.present? && PostingAccess.allowed?(user: member)

        curation = PostCommunityCuration.lock.find(curation_id)
        parent = find_parent(curation:, comment_id:)
        reply = parent.publish_reply(author: member, body:)
        curation.protect_from_contributions! if reply.persisted?
        { curation:, parent:, reply: }
      end
    end

    def self.find_parent(curation:, comment_id:)
      curation.comments.joins(:content).preload(content: :author).find(comment_id)
    end
    private_class_method :find_parent
  end
end

module Community
  class BrowseCurationDiscussion
    def self.call(curation_id:, film_id:, parent_id:, after:, viewer:)
      PreviewAccess.require!(user: viewer)
      curation = PostCommunityCuration.find(curation_id)
      raise Errors::NominationUnavailable unless curation.visible_film_endorsements.exists?(film_id:)

      if parent_id.present?
        parent = curation.comments.find(parent_id)
        raise Errors::NominationUnavailable unless parent.discussion_film_id == film_id
      end

      { curation:, film_id:, parent_id:, after:, discussion: CurationDiscussion.new(curation:),
        can_reply: PostingAccess.allowed?(user: viewer) }
    end
  end
end

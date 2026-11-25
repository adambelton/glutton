module Community
  module Discussions
    class BrowseCurationDiscussion
      def self.call(curation_id:, film_id:, parent_id:, after:, viewer:)
        Membership::Access.require!(user: viewer)
        curation = PostCommunityCuration.find(curation_id)
        raise Errors::NominationUnavailable unless curation.visible_film_endorsements.exists?(film_id:)

        if parent_id.present?
          parent = curation.comments.find(parent_id)
          raise Errors::NominationUnavailable unless CurationDiscussion.film_id_for(parent) == film_id
        end

        { curation:, film_id:, parent_id:, after:, discussion: CurationDiscussion.new(curation:),
          can_reply: Membership::PostingAccess.allowed?(user: viewer) }
      end
    end
  end
end

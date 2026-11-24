module Community
  class WithCurationNomination
    def self.call(curation_id:, user_id:, film_id:)
      PostCommunityCuration.transaction do
        viewer = Identity::UserRegistered.lock.find_by(id: user_id)
        raise Errors::MembershipRequired unless viewer.present? && PreviewAccess.allowed?(user: viewer)

        curation = PostCommunityCuration.lock.find(curation_id)
        raise Errors::NominationUnavailable unless curation.visible_film_endorsements.exists?(film_id:)

        yield viewer.id, film_id
      end
    end
  end
end

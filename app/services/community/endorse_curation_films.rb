module Community
  class EndorseCurationFilms
    def self.load_for_endorsement(curation_id:, member:)
      raise Errors::PostingUnavailable unless PostingAccess.allowed?(user: member)

      curation = PostCommunityCuration.find(curation_id)
      { curation:, films: choices(curation:, member:) }
    end

    def self.choices(curation:, member:)
      endorsed_ids = curation.film_endorsements.where(user: member).select(:film_id)
      EligibleCurationFilms.new(member:).choices(excluding_film_ids: endorsed_ids)
    end

    def self.call(curation_id:, member_id:, film_ids:, comments:)
      PostCommunityCuration.transaction do
        member = Identity::UserRegistered.lock.find_by(id: member_id)
        raise Errors::PostingUnavailable unless member.present? && PostingAccess.allowed?(user: member)

        curation = PostCommunityCuration.lock.find(curation_id)
        curation.respond(member:, film_ids:, comments:) do |selected_ids|
          EligibleCurationFilms.new(member:).lock_for_submission(film_ids: selected_ids)
        end
      end
    end
  end
end

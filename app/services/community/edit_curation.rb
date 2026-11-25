module Community
  class EditCuration
    def self.load_for_edit(curation_id:, member:)
      curation = PostCommunityCuration.find(curation_id)
      raise Errors::CurationEditUnavailable unless curation.can_edit?(member:) || curation.can_edit_additional_description?(member:)

      curation
    end

    def self.call(curation_id:, member_id:, title:, prompt:)
      PostCommunityCuration.transaction do
        member = Identity::UserRegistered.lock.find_by(id: member_id)
        raise Errors::CurationEditUnavailable unless member.present?

        PostCommunityCuration.lock.find(curation_id).edit_text(member:, title:, prompt:)
      end
    end
  end
end

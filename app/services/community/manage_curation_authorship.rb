module Community
  class ManageCurationAuthorship
    def self.update_description(curation_id:, member_id:, additional_description:)
      with_curation(curation_id:, member_id:) do |curation, member|
        curation.edit_additional_description(member:, additional_description:)
      end
    end

    def self.disassociate(curation_id:, member_id:)
      with_curation(curation_id:, member_id:) do |curation, member|
        curation.disassociate!(member:)
      end
    end

    def self.with_curation(curation_id:, member_id:)
      PostCommunityCuration.transaction do
        member = Identity::UserRegistered.lock.find_by(id: member_id)
        raise Errors::CurationEditUnavailable unless member.present?

        yield PostCommunityCuration.lock.find(curation_id), member
      end
    end
    private_class_method :with_curation
  end
end

module Community
  module Curations
    class DeleteCuration
      def self.call(curation_id:, member_id:)
        PostCommunityCuration.transaction do
          member = Identity::UserRegistered.lock.find_by(id: member_id)
          raise Errors::CurationDeletionUnavailable unless member.present?

          PostCommunityCuration.lock.find(curation_id).delete_curation!(member:)
        end
      end
    end
  end
end

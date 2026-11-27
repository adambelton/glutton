module Community
  module Curations
    class DeleteCuration
      def self.call(curation_id:, community_user:)
        Membership::WithProfileForUpdate.call(community_user:) do |community_user|
          raise Errors::CurationDeletionUnavailable unless community_user.present?

          PostCommunityCuration.lock.find(curation_id).delete_curation!(community_user:)
        end
      end
    end
  end
end

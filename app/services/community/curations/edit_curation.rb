module Community
  module Curations
    class EditCuration
      def self.load_for_edit(curation_id:, community_user:)
        curation = PostCommunityCuration.find(curation_id)
        raise Errors::CurationEditUnavailable unless curation.can_edit?(community_user:) || curation.can_edit_additional_description?(community_user:)

        curation
      end

      def self.call(curation_id:, community_user:, title:, description:)
        Membership::WithProfileForUpdate.call(community_user:) do |community_user|
          raise Errors::CurationEditUnavailable unless community_user.present?

          PostCommunityCuration.lock.find(curation_id).edit_text(community_user:, title:, description:)
        end
      end
    end
  end
end

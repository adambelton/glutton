module Community
  module Curations
    class ManageCurationAuthorship
      def self.update_description(curation_id:, community_user:, additional_description:)
        with_curation(curation_id:, community_user:) do |curation, community_user|
          curation.edit_additional_description(community_user:, additional_description:)
        end
      end

      def self.disassociate(curation_id:, community_user:)
        with_curation(curation_id:, community_user:) do |curation, community_user|
          curation.disassociate!(community_user:)
        end
      end

      def self.with_curation(curation_id:, community_user:)
        Membership::WithProfileForUpdate.call(community_user:) do |community_user|
          raise Errors::CurationEditUnavailable unless community_user.present?

          yield PostCommunityCuration.lock.find(curation_id), community_user
        end
      end
      private_class_method :with_curation
    end
  end
end

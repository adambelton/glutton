module Community
  module Membership
    class ManageProfile
      def initialize(community_user:)
        @community_user = community_user
      end

      def change_community_username(community_username:)
        with_profile { |community_user| community_user.change_community_username!(community_username:) }
      end

      def choose_community_avatar(preset:)
        with_profile { |community_user| community_user.choose_community_avatar!(preset:) }
      end

      private

      def with_profile
        raise Errors::CodeOfConductRequired unless @community_user.present?

        WithProfileForUpdate.call(community_user: @community_user) do |community_user|
          raise Errors::MembershipRequired unless community_user.present?

          Access.require!(user: community_user.user)
          yield community_user
        end
      end
    end
  end
end

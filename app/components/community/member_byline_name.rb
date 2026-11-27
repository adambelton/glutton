module Community
  class MemberBylineName < Shared::Base
    def initialize(community_user:)
      @community_user = community_user
    end

    def view_template
      strong do
        a(href: community_member_path(@community_user), class: "community-profile-link", data: { turbo_frame: "_top" }) do
          @community_user.community_username.presence || t("community.curations.member")
        end
      end
    end
  end
end

module Community
  class MemberAvatar < Shared::Base
    include Phlex::Rails::Helpers::ImagePath

    def initialize(community_user:)
      @community_user = community_user
    end

    def view_template
      return if @community_user.community_avatar_preset.blank?

      img(class: "community-member-avatar", src: image_path("community-avatars/#{@community_user.community_avatar_preset}.png"),
        alt: "", width: 32, height: 32, loading: "lazy")
    end
  end
end

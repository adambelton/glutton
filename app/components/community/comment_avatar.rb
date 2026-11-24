module Community
  class CommentAvatar < Shared::Base
    include Phlex::Rails::Helpers::ImagePath

    def initialize(member:)
      @member = member
    end

    def view_template
      return if @member.community_avatar_preset.blank?

      img(class: "community-comment-avatar", src: image_path("community-avatars/#{@member.community_avatar_preset}.png"),
        alt: "", width: 32, height: 32, loading: "lazy")
    end
  end
end

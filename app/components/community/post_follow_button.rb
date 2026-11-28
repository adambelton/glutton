module Community
  class PostFollowButton < Shared::Base
    def initialize(url:, following:, id: nil, label: nil)
      @url, @following, @id, @label = url, following, id, label
    end

    def view_template
      status = t(@following ? "community.notifications.following" : "community.notifications.follow")
      label = t("community.notifications.follow_control", label: @label, status:) if @label.present?

      form_with(url: @url, method: :patch, class: "community-post-follow-form", id: @id) do
        render RubyUI::Button.new(variant: :plain, type: :submit, name: "following", value: @following ? "0" : "1",
          class: "community-post-tag community-post-follow", data: { following: @following.to_s },
          aria: { label: }) { status }
      end
    end
  end
end

module Community
  class DebriefFollowButton < Shared::Base
    def initialize(debrief:, viewer:)
      @debrief = debrief
      @following = Notifications::ManageSettings.following_debrief?(viewer:, debrief:)
    end

    def view_template
      form_with(url: community_debrief_notification_path(@debrief), method: :patch,
        class: "community-debrief-follow-form", id: "debrief-notifications") do
        render RubyUI::Button.new(variant: :plain, type: :submit, name: "following", value: @following ? "0" : "1",
          class: "community-post-tag community-debrief-follow", data: { following: @following.to_s }) do
          t(@following ? "community.notifications.following" : "community.notifications.follow")
        end
      end
    end
  end
end

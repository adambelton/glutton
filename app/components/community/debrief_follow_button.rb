module Community
  class DebriefFollowButton < Shared::Base
    def initialize(debrief:, viewer:)
      @debrief = debrief
      @following = Notifications::ManageSettings.following_debrief?(viewer:, debrief:)
    end

    def view_template
      render PostFollowButton.new(url: community_debrief_notification_path(@debrief), id: "debrief-notifications", following: @following)
    end
  end
end

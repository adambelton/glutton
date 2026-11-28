module Community
  class NotificationSettingsForm < Shared::Base
    def initialize(preferences:, messages:)
      @selected_ratings = preferences.debrief.selected_ratings
      @direct_replies = preferences.discussion.direct_replies
      @messages = messages
    end

    def view_template
      section(aria: { labelledby: "notification-settings" }) do
        h2(id: "notification-settings") { t("community.notifications.title") }
        p(class: "muted") { t("community.notifications.debrief_hint") }
        errors(@messages)
        baseline = { "rating_values[]" => @selected_ratings, direct_replies: @direct_replies ? %w[0 1] : [ "0" ] }
        form_with(url: account_community_notifications_path, method: :patch, class: "community-notification-settings",
          data: track_form_changes(baseline:, controller: "debrief-preference")) do
          fieldset(class: "community-notification-ratings") do
            legend { t("community.notifications.debrief_label") }
            FilmDebriefNotificationPreference::RATING_OPTIONS.each do |value|
              label do
                input(type: "checkbox", name: "rating_values[]", value:, checked: @selected_ratings.include?(value),
                  data: { debrief_preference_target: "rating" })
                plain(value == FilmDebriefNotificationPreference::UNRATED ? t("community.notifications.unrated") : rating_vocabulary.label(value))
              end
            end
            div(class: "community-notification-selection") do
              render Shared::GhostButton.new(type: :button, hidden: true,
                data: { action: "debrief-preference#selectRatings", debrief_preference_target: "shortcut", debrief_preference_selected_param: "true" }) do
                t("community.notifications.all")
              end
              render Shared::GhostButton.new(type: :button, hidden: true,
                data: { action: "debrief-preference#selectRatings", debrief_preference_target: "shortcut", debrief_preference_selected_param: "false" }) do
                t("community.notifications.none")
              end
            end
          end
          input(type: "hidden", name: "direct_replies", value: "0")
          label(class: "community-notification-replies") do
            input(type: "checkbox", name: "direct_replies", value: "1", checked: @direct_replies)
            plain t("community.notifications.direct_replies")
          end
          div(class: "ui-actions ui-actions-mobile-full justify-self-stretch") do
            validated_submit(t("community.notifications.save"), class_name: "ui-action-button")
          end
        end
      end
    end
  end
end

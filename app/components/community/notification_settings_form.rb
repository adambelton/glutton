module Community
  class NotificationSettingsForm < Shared::Base
    def initialize(preferences:, messages:)
      @selected_ratings = preferences.debrief.selected_ratings
      @direct_replies = preferences.discussion.direct_replies
      @curation_settings = {
        "authored_curations" => preferences.curation.authored_curations,
        "endorsed_film_comments" => preferences.curation.endorsed_film_comments
      }
      @messages = messages
    end

    def view_template
      section(aria: { labelledby: "notification-settings" }) do
        h2(id: "notification-settings") { t("community.notifications.title") }
        p(class: "muted") { t("community.notifications.debrief_hint") }
        errors(@messages)
        baseline = @curation_settings.merge("direct_replies" => @direct_replies)
          .transform_values { |checked| checked ? %w[0 1] : [ "0" ] }
          .merge("rating_values[]" => @selected_ratings)
        form_with(url: account_community_notifications_path, method: :patch, class: "community-notification-settings",
          data: track_form_changes(baseline:, controller: "debrief-preference")) do
          fieldset(class: "community-notification-ratings", aria: { describedby: "debrief-opening-comments" }) do
            legend { t("community.notifications.debrief_label") }
            p(id: "debrief-opening-comments", class: "basis-full") { t("community.notifications.debrief_opening_comments") }
            FilmDebriefNotificationPreference::RATING_OPTIONS.each do |value|
              label do
                input(type: "checkbox", name: "rating_values[]", value:, checked: @selected_ratings.include?(value),
                  data: { debrief_preference_target: "rating" })
                plain(value == FilmDebriefNotificationPreference::UNRATED ? t("community.notifications.unrated") : rating_vocabulary.label(value))
              end
            end
            div(class: "community-notification-selection ui-actions ui-actions-fixed") do
              render Shared::GhostButton.new(type: :button, class: "ui-action-button", hidden: true,
                data: { action: "debrief-preference#selectRatings", debrief_preference_target: "shortcut", debrief_preference_selected_param: "true" }) do
                t("community.notifications.all")
              end
              render Shared::GhostButton.new(type: :button, class: "ui-action-button", hidden: true,
                data: { action: "debrief-preference#selectRatings", debrief_preference_target: "shortcut", debrief_preference_selected_param: "false" }) do
                t("community.notifications.none")
              end
            end
          end
          fieldset(class: "community-notification-curations") do
            legend { t("community.notifications.curation_label") }
            @curation_settings.each { |name, checked| preference_checkbox(name:, checked:) }
          end
          fieldset do
            legend { t("community.notifications.discussion_label") }
            preference_checkbox(name: "direct_replies", checked: @direct_replies)
          end
          div(class: "ui-actions ui-actions-fixed ui-actions-mobile-full justify-self-stretch") do
            validated_submit(t("community.notifications.save"), class_name: "ui-action-button")
          end
        end
      end
    end

    private

    def preference_checkbox(name:, checked:)
      input(type: "hidden", name:, value: "0")
      label(class: "community-notification-replies") do
        input(type: "checkbox", name:, value: "1", checked:)
        plain t("community.notifications.#{name}")
      end
    end
  end
end

module Shared
  class Layout < Base
    register_value_helper :request

    def initialize(title:, pending_reminder: true, account_controls: true)
      @title, @pending_reminder, @account_controls = title, pending_reminder, account_controls
    end

    def view_template
      user = current_user if @account_controls
      community_unlocked = user.present? && Community::PreviewAccess.allowed?(user:)
      wordmark_path = user.present? ? new_rating_path : root_path
      recommendations_unlocked = Recommendations::CandidateSelection::RecommendationUnlock.unlocked?(user:) if user.present?
      watch_unlock = user.present? && !recommendations_unlocked &&
        Recommendations::CandidateSelection::RecommendationUnlock.enough_ratings_submitted?(user:)
      header_data = if watch_unlock
        { controller: "recommendations-unlock", recommendations_unlock_url_value: availability_recommendation_path }
      end

      render Document.new(title: @title) do
        a(href: "#main-content", class: "skip-link") { t("ui.skip") }
        header(class: "ui-header", data: header_data) do
          div(class: "ui-width ui-header-inner") do
            a(href: wordmark_path, class: "wordmark", aria: { label: t("ui.wordmark") }) { t("ui.wordmark") }
            if user.present?
              primary_navigation(user, recommendations_unlocked:, community_unlocked:)
              mobile_navigation(user, recommendations_unlocked:, community_unlocked:)
            end
            render ThemeToggle.new
            if user.nil? || user.can_register?
              div(class: "ui-auth-links") do
                render Identity::AccountEntryControls.new(guest_entry: @account_controls && user.nil?)
                render Identity::DiscardGuestConfirmationDialog.new if user&.can_register?
              end
            end
          end
        end
        if user&.can_register?
          aside(class: "guest-banner", aria: { label: t("identity.entry.guest_banner_label") }) do
            div(class: "ui-width") do
              span { t("identity.entry.guest_banner") }
              plain " "
              text_link(t("identity.entry.save_progress"), new_registration_path)
            end
          end
        end
        div(class: "ui-notifications") do
          render Toast.new(message: flash[:notice]) if flash[:notice].present?
          if @pending_reminder
            render Identity::RegistrationReminder.new(registration: current_pending_registration)
          end
          p(role: "alert", class: "ui-alert") { flash[:alert] } if flash[:alert].present?
        end
        div(class: "ui-width ui-content") do
          yield user.present? && mobile_navigation_title == @title
        end
      end
    end

    private

    def primary_navigation(user, recommendations_unlocked:, community_unlocked:)
      nav(aria: { label: t("ui.navigation") }, class: "ui-nav ui-nav-wide") do
        a(href: new_rating_path) { t("ratings.browser.title") }
        render Recommendations::RecommendationsNavLink.new(unlocked: recommendations_unlocked)
        a(href: library_path) { t("library.browser.title") }
        if community_unlocked
          a(href: community_path) { t("community.title") }
        else
          render LockedNavigationLink.new(label: t("community.title"), tooltip: t("community.coming_soon"), tooltip_id: "community-nav-tooltip")
        end
        a(href: account_settings_path) { t("account.title") } if user.can_view_account?
        a(href: admin_path) { t("admin.title") } if user.superuser?
      end
    end

    def mobile_navigation_title
      case request.path.split("/")[1]
      when "rating" then t("ratings.browser.title")
      when "recommendation" then t("recommendations.title")
      when "library" then t("library.browser.title")
      when "community" then t("community.title")
      when "account" then t("account.title")
      end
    end

    def mobile_navigation(user, recommendations_unlocked:, community_unlocked:)
      current_section = request.path.split("/")[1]
      select(class: "ui-primary-navigation ui-input", aria: { label: t("ui.navigation") },
        data: { controller: "mobile-navigation", action: "change->mobile-navigation#navigate" }) do
        option(value: "", disabled: true, selected: !%w[ rating recommendation library community account ].include?(current_section)) { t("ui.navigation") }
        navigation_option("rating", new_rating_path, t("ratings.browser.title"), current_section:)
        recommendation_label = t("recommendations.title")
        unless recommendations_unlocked
          recommendation_label = t("ui.locked_navigation_option", label: recommendation_label,
            reason: t("recommendations.navigation_locked", required: Recommendations::CandidateSelection::NextCandidate::MINIMUM_ASSESSED_FILMS))
        end
        navigation_option("recommendation", recommendation_path, recommendation_label,
          current_section:, disabled: !recommendations_unlocked,
          data: { recommendations_unlock_target: "option", unlocked_label: t("recommendations.title") })
        navigation_option("library", library_path, t("library.browser.title"), current_section:)
        community_label = t("community.title")
        unless community_unlocked
          community_label = t("ui.locked_navigation_option", label: community_label, reason: t("community.coming_soon"))
        end
        navigation_option("community", community_path, community_label, current_section:, disabled: !community_unlocked)
        navigation_option("account", account_settings_path, t("account.title"), current_section:) if user.can_view_account?
        navigation_option("admin", admin_path, t("admin.title"), current_section:) if user.superuser?
      end
    end

    def navigation_option(section, path, label, current_section:, disabled: false, **attrs)
      option(value: path, selected: section == current_section, disabled:, **attrs) { label }
    end
  end
end

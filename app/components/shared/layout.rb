module Shared
  class Layout < Base
    register_value_helper :request

    def initialize(title:, pending_reminder: true, header_entry_on_mobile: true)
      @title, @pending_reminder, @header_entry_on_mobile = title, pending_reminder, header_entry_on_mobile
    end

    def view_template
      user = current_user
      community_access = user.present? && Community::Membership::Access.allowed?(user:)
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
              primary_navigation(user, recommendations_unlocked:, community_access:)
              mobile_navigation(user, recommendations_unlocked:, community_access:)
            end
            if user.present? && user.can_view_account?
              div(class: "ui-header-tools") do
                render Community::NotificationBell.new(viewer: user)
                render ThemeToggle.new
              end
            else
              render ThemeToggle.new
            end
            if user.nil? || user.can_register?
              div(class: [ "ui-auth-links", ("ui-auth-links-desktop" unless @header_entry_on_mobile) ]) do
                render Identity::AccountEntryControls.new(guest_entry: user.nil?)
                render Identity::DiscardGuestConfirmationDialog.new if user&.can_register?
              end
            end
          end
        end
        if user&.can_register?
          render HeaderBanner.new(message: t("identity.entry.guest_banner"), link_label: t("identity.entry.save_progress"),
            link_path: new_registration_path, class_name: "guest-banner", aria: { label: t("identity.entry.guest_banner_label") })
        elsif community_access && community_page? && Community::Membership::Access.suspended?(user:)
          render Community::SuspensionNotice.new(in_header: true)
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

    def community_page?
      request.path == community_path || request.path.start_with?("#{community_path}/")
    end

    def primary_navigation(user, recommendations_unlocked:, community_access:)
      nav(aria: { label: t("ui.navigation") }, class: "ui-nav ui-nav-wide") do
        a(href: new_rating_path) { t("ratings.browser.title") }
        render Recommendations::RecommendationsNavLink.new(unlocked: recommendations_unlocked)
        a(href: library_path) { t("library.browser.title") }
        a(href: community_path) { t("community.title") } if community_access
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
      when "notifications" then t("community.notifications.title")
      end
    end

    def mobile_navigation(user, recommendations_unlocked:, community_access:)
      current_section = request.path.split("/")[1]
      select(class: "ui-primary-navigation ui-input", aria: { label: t("ui.navigation") },
        data: { controller: "mobile-navigation", action: "change->mobile-navigation#navigate" }) do
        option(value: "", disabled: true, selected: !%w[ rating recommendation library community account notifications ].include?(current_section)) { t("ui.navigation") }
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
        navigation_option("community", community_path, t("community.title"), current_section:) if community_access
        navigation_option("account", account_settings_path, t("account.title"), current_section:) if user.can_view_account?
        navigation_option("admin", admin_path, t("admin.title"), current_section:) if user.superuser?
        navigation_option("notifications", notifications_path, t("community.notifications.title"), current_section:) if user.can_view_account?
      end
    end

    def navigation_option(section, path, label, current_section:, disabled: false, **attrs)
      option(value: path, selected: section == current_section, disabled:, **attrs) { label }
    end
  end
end

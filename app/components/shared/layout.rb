module Shared
  class Layout < Base
    def initialize(title:, pending_reminder: true, account_controls: true)
      @title, @pending_reminder, @account_controls = title, pending_reminder, account_controls
    end

    def view_template
      user = current_user if @account_controls
      render Document.new(title: @title) do
        a(href: "#main-content", class: "skip-link") { t("ui.skip") }
        header(class: "ui-header") do
          div(class: "ui-width ui-header-inner") do
            a(href: root_path, class: "wordmark", aria: { label: t("ui.wordmark") }) { t("ui.wordmark") }
            if user.present?
              nav(aria: { label: t("ui.navigation") }, class: "ui-nav") do
                a(href: new_rating_path) { t("ratings.browser.title") }
                a(href: library_path) { t("library.browser.title") }
                if user&.superuser?
                  a(href: registry_root_path) { t("registry.title") }
                  a(href: account_path) { t("account.title") }
                end
              end
            end
            render ThemeToggle.new
            div(class: "ui-auth-links") do
              if user.nil? || user.can_register?
                render Identity::EntryActions.new(guest_entry: @account_controls && user.nil?)
              else
                render Shared::ActionButton.new(text: t("ui.log_out"), url: session_path, method: :delete)
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
        div(class: "ui-width ui-content") do
          render Toast.new(message: flash[:notice]) if flash[:notice].present?
          if @pending_reminder
            render Identity::RegistrationReminder.new(registration: current_pending_registration)
          end
          p(role: "alert", class: "ui-alert") { flash[:alert] } if flash[:alert].present?
          yield
        end
      end
    end
  end
end

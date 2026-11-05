module UI
  class Layout < Base
    def initialize(title:, pending_reminder: true, account_controls: true)
      @title, @pending_reminder, @account_controls = title, pending_reminder, account_controls
    end

    def view_template
      render Document.new(title: @title) do
        a(href: "#main-content", class: "skip-link") { t("ui.skip") }
        header(class: "ui-header") do
          div(class: "ui-width ui-header-inner") do
            a(href: root_path, class: "wordmark", aria: { label: t("ui.wordmark") }) { t("ui.wordmark") }
            nav(aria: { label: t("ui.navigation") }, class: "ui-nav") do
              a(href: new_rating_path) { t("ratings.browser.title") }
              a(href: library_path) { t("library.browser.title") }
              if @account_controls && current_user&.superuser?
                a(href: registry_root_path) { t("registry.title") }
              end
            end
            render ThemeToggle.new
            if @account_controls
              details(class: "ui-account-menu") do
                summary { t("ui.account") }
                div(class: "ui-account-panel") do
                  render Identity::AccountStatus.new(user: current_user)
                end
              end
            end
          end
        end
        div(class: "ui-width ui-content") do
          if @pending_reminder
            render Identity::RegistrationReminder.new(registration: current_pending_registration)
          end
          p(role: "alert", class: "ui-alert") { flash[:alert] } if flash[:alert].present?
          p(role: "status", class: "ui-notice") { flash[:notice] } if flash[:notice].present?
          yield
        end
      end
    end
  end
end

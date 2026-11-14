module Views
  module Identity
    class AccountSettings < ::Views::Base
      def initialize(email_address:, validation_errors:, open_dialog:)
        @email_address = email_address
        @validation_errors = validation_errors
        @open_dialog = open_dialog
      end

      def view_template
        page(title: t("account.title"), class: "account-page", heading_outside_card: true) do
          render ::Identity::AccountNavigation.new(section: :settings)
          errors(@validation_errors) if @open_dialog.nil?
          section do
            h2 { t("identity.settings.login_details") }
            div(class: "account-settings-row") do
              div(class: "account-settings-field") do
                strong { t("identity.settings.email") }
                p { @email_address }
              end
              credential_dialog(:email, title: t("identity.settings.change_email")) do
                form_with(url: account_email_path) do
                  field(name: "email_address", id: "new_email_address", label: t("identity.settings.new_email"),
                    type: :email, required: true, autocomplete: "email")
                  current_password_field("email_current_password")
                  credential_actions(t("identity.settings.send_email"))
                end
              end
            end
            div(class: "account-settings-row") do
              div(class: "account-settings-field") do
                strong { t("identity.settings.password") }
                p(aria: { label: t("identity.settings.password_hidden") }) { "********" }
              end
              credential_dialog(:password, title: t("identity.settings.change_password")) do
                form_with(url: account_password_path, method: :patch) do
                  current_password_field("change_current_password")
                  field(name: "password", id: "new_password", label: t("identity.recovery.new_password"),
                    type: :password, required: true, autocomplete: "new-password")
                  field(name: "password_confirmation", id: "confirm_new_password", label: t("identity.registration.password_confirmation"),
                    type: :password, required: true, autocomplete: "new-password")
                  credential_actions(t("identity.settings.change_password"))
                end
              end
            end
          end
          section(class: "account-logout") do
            h2 { t("ui.log_out") }
            render Shared::ActionForm.new(url: session_path, method: :delete) do
              render Shared::GhostButton.new(type: :submit, class: "ui-action-button account-settings-action") { t("ui.log_out") }
            end
          end
          section(class: "account-deletion") do
            h2 { t("identity.settings.delete_title") }
            render ::Identity::DeleteAccountConfirmationDialog.new
          end
        end
      end

      private

      def credential_dialog(kind, title:)
        title_id = "account-#{kind}-dialog-title"
        open = @open_dialog == kind
        div(data: { controller: "confirmation-dialog", confirmation_dialog_auto_open_value: open }) do
          render Shared::GhostButton.new(class: "ui-action-button", aria: { haspopup: "dialog" },
            data: { action: "confirmation-dialog#open" }) { title }
          tag(:dialog, class: "ui-card ui-confirmation-dialog", aria: { labelledby: title_id },
            data: { confirmation_dialog_target: "dialog", action: "turbo:before-cache@document->confirmation-dialog#close" }) do
            h2(id: title_id) { title }
            errors(@validation_errors) if open
            yield
          end
        end
      end

      def credential_actions(label)
        div(class: "ui-actions") do
          render Shared::GhostButton.new(class: "ui-action-button",
            data: { action: "confirmation-dialog#close" }) { t("identity.settings.cancel") }
          render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button") { label }
        end
      end

      def current_password_field(id)
        field(name: "current_password", id:, label: t("identity.settings.current_password"), type: :password,
          required: true, autocomplete: "current-password")
      end
    end
  end
end

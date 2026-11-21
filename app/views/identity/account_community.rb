module Views
  module Identity
    class AccountCommunity < ::Views::Base
      def initialize(community_username:, editing_username:, form_username:, username_errors:)
        @community_username = community_username
        @editing_username = editing_username
        @form_username = form_username
        @username_errors = username_errors
      end

      def view_template
        page(title: t("account.title"), class: "account-page", heading_outside_card: true) do
          render ::Identity::AccountNavigation.new(section: :community)
          @editing_username || @community_username.blank? ? username_form : saved_username
          render ::Community::ConductAcceptanceForm.new(user: current_user, source: "account")
        end
      end

      private

      def saved_username
        div(class: "account-settings-row") do
          div(class: "account-settings-field") do
            strong { t("identity.settings.community_username.label") }
            p { @community_username }
          end
          render Shared::ActionForm.new(url: account_community_path, method: :get, params: { edit: "username" }) do
            render Shared::GhostButton.new(type: :submit, class: "ui-action-button") { t("identity.settings.community_username.change") }
          end
        end
      end

      def username_form
        errors(@username_errors)
        form_with(url: account_community_username_path, method: :patch, class: "account-community-form") do
          field(name: "community_username", id: "community_username", label: t("identity.settings.community_username.label"),
            value: @form_username, required: true, autocomplete: "off", spellcheck: false, autofocus: @editing_username,
            data: { bwignore: "true", "1p-ignore": "true" },
            aria: { describedby: "community_username_hint", invalid: @username_errors.any?.to_s })
          p(id: "community_username_hint", class: "muted account-community-hint") { t("identity.settings.community_username.hint") }
          div(class: "account-community-actions") do
            render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button") { t("identity.settings.community_username.save") }
            if @community_username.present?
              render Shared::GhostButton.new(type: :submit, form: "cancel-community-username", class: "ui-action-button") { t("identity.settings.cancel") }
            end
          end
        end
        form_with(url: account_community_path, method: :get, id: "cancel-community-username") { } if @community_username.present?
      end
    end
  end
end

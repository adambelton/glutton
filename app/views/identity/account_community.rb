module Views
  module Identity
    class AccountCommunity < ::Views::Base
      include Phlex::Rails::Helpers::ImagePath

      def initialize(community_username:, editing_username:, form_username:, username_errors:,
        community_avatar_preset:, editing_avatar:, avatar_errors:)
        @community_username = community_username
        @editing_username = editing_username
        @form_username = form_username
        @username_errors = username_errors
        @community_avatar_preset = community_avatar_preset
        @editing_avatar = editing_avatar
        @avatar_errors = avatar_errors
      end

      def view_template
        page(title: t("account.title"), class: "account-page", heading_outside_card: true) do
          render ::Identity::AccountNavigation.new(section: :community)
          code = ::Community::CodeOfConduct.current
          if code.accepted_by?(member: current_user)
            @editing_username || @community_username.blank? ? username_form : saved_username
            @editing_avatar ? avatar_form : saved_avatar
          end
          render ::Community::ConductAcceptanceForm.new(user: current_user, code:)
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
        form_with(url: account_community_username_path, method: :patch, class: "account-community-form",
          data: track_form_changes(baseline: { community_username: @community_username })) do
          field(name: "community_username", id: "community_username", label: t("identity.settings.community_username.label"),
            value: @form_username, required: true, autocomplete: "off", spellcheck: false, autofocus: @editing_username,
            data: { bwignore: "true", "1p-ignore": "true" },
            aria: { describedby: "community_username_hint", invalid: @username_errors.any?.to_s })
          p(id: "community_username_hint", class: "muted account-community-hint") { t("identity.settings.community_username.hint") }
          div(class: "account-community-actions") do
            validated_submit(t("identity.settings.community_username.save"), class_name: "ui-action-button")
            if @community_username.present?
              render Shared::GhostButton.new(type: :submit, form: "cancel-community-username", class: "ui-action-button") { t("identity.settings.cancel") }
            end
          end
        end
        form_with(url: account_community_path, method: :get, id: "cancel-community-username") { } if @community_username.present?
      end

      def saved_avatar
        div(class: "account-settings-row") do
          div(class: "account-avatar-current") do
            strong { t("identity.settings.community_avatar.label") }
            if @community_avatar_preset.present?
              avatar_art(@community_avatar_preset, alt: avatar_name(@community_avatar_preset))
            end
          end
          action = @community_avatar_preset.present? ? :change : :choose
          render Shared::ActionForm.new(url: account_community_path, method: :get, params: { edit: "avatar" }) do
            render Shared::GhostButton.new(type: :submit, class: "ui-action-button") { t("identity.settings.community_avatar.#{action}") }
          end
        end
      end

      def avatar_form
        errors(@avatar_errors)
        form_with(url: account_community_avatar_path, method: :patch, class: "account-avatar-form",
          data: track_form_changes(baseline: { community_avatar_preset: @community_avatar_preset })) do
          fieldset do
            legend { t("identity.settings.community_avatar.choose") }
            div(class: "account-avatar-grid") do
              ::Identity::UserRegistered::COMMUNITY_AVATAR_PRESETS.each do |preset|
                label(class: "account-avatar-choice") do
                  input(type: "radio", class: "sr-only", name: "community_avatar_preset", value: preset,
                    checked: preset == @community_avatar_preset, required: true, aria: { label: avatar_name(preset) })
                  span(class: "account-avatar-option") { avatar_art(preset) }
                end
              end
            end
          end
          div(class: "account-community-actions") do
            validated_submit(t("identity.settings.community_avatar.save"), class_name: "ui-action-button")
            render Shared::GhostButton.new(type: :submit, form: "cancel-community-avatar", class: "ui-action-button") do
              t("identity.settings.cancel")
            end
          end
        end
        form_with(url: account_community_path, method: :get, id: "cancel-community-avatar") { }
      end

      def avatar_art(preset, alt: "")
        img(class: "community-avatar-art", src: image_path("community-avatars/#{preset}.png"),
          alt:, width: 512, height: 512, loading: "lazy")
      end

      def avatar_name(preset)
        t("identity.settings.community_avatar.presets.#{preset}")
      end
    end
  end
end

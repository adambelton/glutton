module Views
  module Community
    class Profile < ::Views::Base
      include Phlex::Rails::Helpers::ImagePath

      def initialize(community_user:, blocks:, suspended:, code:, accepted:, editing_username: false,
        form_username: community_user&.community_username, username_errors: [], editing_avatar: false, avatar_errors: [])
        @community_user = community_user
        @blocks = blocks
        @suspended, @code, @accepted = suspended, code, accepted
        @community_username = community_user&.community_username
        @editing_username = editing_username
        @form_username = form_username
        @username_errors = username_errors
        @community_avatar_preset = community_user&.community_avatar_preset
        @editing_avatar = editing_avatar
        @avatar_errors = avatar_errors
      end

      def view_template
        page(title: t("account.title"), class: "account-page", heading_outside_card: true) do
          render ::Identity::AccountNavigation.new(section: :community)
          render ::Community::SuspensionNotice.new if @suspended
          if @community_user.present? && @accepted
            !@suspended && (@editing_username || @community_username.blank?) ? username_form : saved_username
            !@suspended && @editing_avatar ? avatar_form : saved_avatar
          end
          render ::Community::ConductAcceptanceForm.new(accepted: @accepted, code: @code)
          blocked_members if @community_user.present?
        end
      end

      private

      def blocked_members
        section(aria: { labelledby: "blocked-members" }) do
          h2(id: "blocked-members") { t("community.member_blocks.heading") }
          if @blocks.present?
            ul(class: "account-blocked-members", role: "list") do
              @blocks.each do |block|
                li(class: "account-settings-row") do
                  div(class: "account-settings-field") do
                    strong { block.blocked.community_username.presence || t("community.curations.member") }
                    p do
                      time(datetime: block.created_at.iso8601) do
                        t("community.member_blocks.blocked_at", time: I18n.l(block.created_at, format: :long))
                      end
                    end
                  end
                  render Shared::ActionForm.new(url: community_member_block_path(block.blocked_id), method: :delete) do
                    render Shared::GhostButton.new(type: :submit, class: "ui-action-button") { t("community.member_blocks.unblock") }
                  end
                end
              end
            end
          else
            p(class: "muted") { t("community.member_blocks.empty") }
          end
        end
      end

      def saved_username
        div(class: "account-settings-row") do
          div(class: "account-settings-field") do
            strong { t("community.profile.username.label") }
            p { @community_username }
          end
          unless @suspended
            render Shared::ActionForm.new(url: account_community_path, method: :get, params: { edit: "username" }) do
              render Shared::GhostButton.new(type: :submit, class: "ui-action-button") { t("community.profile.username.change") }
            end
          end
        end
      end

      def username_form
        errors(@username_errors)
        form_with(url: account_community_username_path, method: :patch, class: "account-community-form",
          data: track_form_changes(baseline: { community_username: @community_username })) do
          field(name: "community_username", id: "community_username", label: t("community.profile.username.label"),
            value: @form_username, required: true, autocomplete: "off", spellcheck: false, autofocus: @editing_username,
            data: { bwignore: "true", "1p-ignore": "true" },
            aria: { describedby: "community_username_hint", invalid: @username_errors.any?.to_s })
          p(id: "community_username_hint", class: "muted account-community-hint") { t("community.profile.username.hint") }
          div(class: "account-community-actions") do
            validated_submit(t("community.profile.username.save"), class_name: "ui-action-button")
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
            strong { t("community.profile.avatar.label") }
            if @community_avatar_preset.present?
              avatar_art(@community_avatar_preset, alt: avatar_name(@community_avatar_preset))
            end
          end
          unless @suspended
            action = @community_avatar_preset.present? ? :change : :choose
            render Shared::ActionForm.new(url: account_community_path, method: :get, params: { edit: "avatar" }) do
              render Shared::GhostButton.new(type: :submit, class: "ui-action-button") { t("community.profile.avatar.#{action}") }
            end
          end
        end
      end

      def avatar_form
        errors(@avatar_errors)
        form_with(url: account_community_avatar_path, method: :patch, class: "account-avatar-form",
          data: track_form_changes(baseline: { community_avatar_preset: @community_avatar_preset })) do
          fieldset do
            legend { t("community.profile.avatar.choose") }
            div(class: "account-avatar-grid") do
              ::Community::CommunityUser::AVATAR_PRESETS.each do |preset|
                label(class: "account-avatar-choice") do
                  input(type: "radio", class: "sr-only", name: "community_avatar_preset", value: preset,
                    checked: preset == @community_avatar_preset, required: true, aria: { label: avatar_name(preset) })
                  span(class: "account-avatar-option") { avatar_art(preset) }
                end
              end
            end
          end
          div(class: "account-community-actions") do
            validated_submit(t("community.profile.avatar.save"), class_name: "ui-action-button")
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
        t("community.profile.avatar.presets.#{preset}")
      end
    end
  end
end

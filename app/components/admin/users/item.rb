module Admin
  module Users
    class Item < Shared::Base
      def initialize(user:, sessions:)
        @user, @sessions = user, sessions
      end

      def view_template
        section(class: "admin-detail-section", aria: { labelledby: "account-details-heading" }) do
          div(class: "admin-section-title") do
            h2(id: "account-details-heading") { t("identity.user_administration.account_details") }
            a(href: glutton_profile_admin_user_path(@user.id), class: "record-link") { t("identity.user_administration.profile") }
          end
          dl(class: "admin-facts") do
            field(:email, @user.email_address)
            field(:type, t("identity.user_administration.types.#{@user.model_name.singular_route_key}"))
            field(:status, t("identity.user_administration.#{@user.active? ? :active : :inactive}"))
            field(:created, I18n.l(@user.created_at, format: :long))
            field(:confirmed, I18n.l(@user.email_confirmed_at, format: :long)) if @user.email_confirmed_at.present?
          end
        end
        section(class: "admin-detail-section", aria: { labelledby: "user-sessions-heading" }) do
          h2(id: "user-sessions-heading") { t("identity.user_administration.sessions") }
          if @sessions.empty?
            p(class: "muted") { t("identity.user_administration.no_sessions") }
          else
            ul(class: "user-administration-sessions") do
              @sessions.each { |session| li { session_row(session) } }
            end
          end
        end
      end

      private

      def field(key, value)
        div do
          dt { t("identity.user_administration.#{key}") }
          dd { value || t("identity.user_administration.none") }
        end
      end

      def session_row(session)
        p { t("identity.user_administration.session", id: session.id, time: I18n.l(session.created_at, format: :long)) }
        render Shared::ActionForm.new(url: session_admin_user_path(@user.id, session.id), method: :delete) do
          render Shared::GhostButton.new(type: :submit, aria: { label: t("identity.user_administration.revoke_label", id: session.id) }) do
            t("identity.user_administration.revoke")
          end
        end
      end
    end
  end
end

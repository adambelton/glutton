module Admin
  module Users
    class Collection < Shared::Base
      def initialize(users:)
        @users = users
      end

      def view_template
        if @users.empty?
          p { t("identity.user_administration.no_users") }
        else
          user_table
        end
      end

      private

      def user_table
        title = t("identity.user_administration.title")
        render RubyUI::Table.new(scroll_label: title, class: "admin-table ui-collection-table user-administration-table") do
          render RubyUI::TableCaption.new(class: "sr-only") { title }
          render RubyUI::TableHeader.new do
            render RubyUI::TableRow.new do
              render Shared::TableCell.new(heading: true) { t("identity.user_administration.account") }
              render Shared::TableCell.new(heading: true) { t("identity.user_administration.status") }
              render Shared::TableCell.new(heading: true, class: "user-created-column") { t("identity.user_administration.created") }
            end
          end
          render RubyUI::TableBody.new do
            @users.each { |user| user_row(user) }
          end
        end
      end

      def user_row(user)
        label = t("identity.user_administration.record_label", id: user.id)
        render RubyUI::TableRow.new do
          render Shared::TableCell.new do
            a(href: admin_user_path(user.id), class: "user-record-link") { user.email_address || label }
            div(class: "user-record-meta") do
              span(class: "user-record-id") { label } if user.email_address.present?
              span(class: "user-created-inline") { created_date(user) }
            end
          end
          render Shared::TableCell.new do
            span(class: "user-record-type") { t("identity.user_administration.types.#{user.model_name.singular_route_key}") }
            status = user.active? ? :active : :inactive
            span(class: "user-status", data: { status: }) { t("identity.user_administration.#{status}") }
          end
          render Shared::TableCell.new(class: "user-created-column") { created_date(user) }
        end
      end

      def created_date(user)
        time(datetime: user.created_at.iso8601) { I18n.l(user.created_at.to_date, format: :user_admin) }
      end
    end
  end
end

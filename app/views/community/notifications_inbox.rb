module Views
  module Community
    class NotificationsInbox < ::Views::Base
      def initialize(items:, next_cursor:)
        @items, @next_cursor = items, next_cursor
      end

      def view_template
        page(title: t("community.notifications.title"), heading_outside_card: true) do
          div(class: "community-inbox-settings") do
            text_link(t("community.notifications.settings"), account_community_path(anchor: "notification-settings"))
          end
          if @items.empty?
            p(class: "muted") { t("community.notifications.empty") }
          else
            ul(class: "community-inbox", role: "list") { @items.each { |item| entry(item) } }
          end
          if @next_cursor.present?
            text_link(t("community.notifications.older"), notifications_path(before: @next_cursor))
          end
        end
      end

      private

      def entry(item)
        comment = item.comment_content.comment
        post = comment.post
        title = post.title.presence || post.film.title
        message = comment.parent_id.present? ? "community.notifications.direct_reply" : "community.notifications.debrief_comment"
        li do
          render Shared::ActionForm.new(url: open_notification_path(item), method: :post) do
            button(type: "submit", class: "community-inbox-entry") do
              if item.read_at.nil?
                span(class: "community-inbox-indicator", aria: { label: t("community.notifications.unread") })
              end
              span { t(message, title:) }
              time(datetime: item.comment_content.created_at.iso8601) { I18n.l(item.comment_content.created_at, format: :long) }
            end
          end
        end
      end
    end
  end
end

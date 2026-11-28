module Community
  class NotificationBell < Shared::Base
    def initialize(viewer:)
      @unread = Notifications::Inbox.new(viewer:).unread?
    end

    def view_template
      label = t(@unread ? "community.notifications.unread_label" : "community.notifications.title")
      a(href: notifications_path, class: "community-notification-bell", aria: { label: }) do
        svg(viewBox: "0 0 24 24", width: "22", height: "22", fill: "none", stroke: "currentColor",
          stroke_width: "1.75", stroke_linecap: "round", stroke_linejoin: "round", aria: { hidden: "true" }) do |icon|
          icon.path(d: "M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4")
        end
        span(class: "community-notification-dot", aria: { hidden: "true" }) if @unread
      end
    end
  end
end

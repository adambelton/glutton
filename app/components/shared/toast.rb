module Shared
  class Toast < Base
    def initialize(message:)
      @message = message
    end

    def view_template
      div(class: "ui-toast", data: { controller: "toast", turbo_temporary: true,
        action: "mouseenter->toast#pause mouseleave->toast#resume focusin->toast#pause focusout->toast#resume visibilitychange@document->toast#visibilityChanged turbo:before-cache@document->toast#dismiss" }) do
        p(role: "status", aria: { atomic: "true" }) { @message }
        button(type: "button", class: "ui-toast-dismiss", aria: { label: t("ui.dismiss_notification") }, data: { action: "toast#dismiss" }) { "×" }
      end
    end
  end
end

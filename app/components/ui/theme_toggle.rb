module UI
  class ThemeToggle < Base
    def view_template
      button(type: "button", class: "theme-toggle", hidden: true, aria: { pressed: "false", label: t("ui.dark_mode") },
        data: { controller: "theme", action: "theme#toggle" }) do
        span(aria: { hidden: "true" }, class: "theme-icon") { "◐" }
      end
    end
  end
end

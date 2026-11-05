module UI
  class ThemeToggle < Base
    def view_template
      button(type: "button", class: "theme-toggle", hidden: true, aria: { pressed: "false" },
        data: { controller: "theme", action: "theme#toggle" }) { t("ui.dark_mode") }
    end
  end
end

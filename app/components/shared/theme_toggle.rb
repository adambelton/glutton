module Shared
  class ThemeToggle < Base
    def view_template
      button(type: "button", class: "theme-toggle", hidden: true, aria: { pressed: "false", label: t("ui.dark_mode") },
        data: { controller: "theme", action: "theme#toggle" }) do
        span(aria: { hidden: "true" }, class: "theme-icon") do
          svg(viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.75", stroke_linecap: "round", stroke_linejoin: "round", class: "theme-moon") do |icon|
            icon.path(d: "M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8Z")
          end
          svg(viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.75", stroke_linecap: "round", class: "theme-sun") do |icon|
            icon.circle(cx: "12", cy: "12", r: "4")
            icon.path(d: "M12 2v2m0 16v2M2 12h2m16 0h2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4")
          end
        end
      end
    end
  end
end

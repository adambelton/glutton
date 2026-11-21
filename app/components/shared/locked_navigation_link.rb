module Shared
  class LockedNavigationLink < Base
    def initialize(label:, tooltip:, tooltip_id:, data: {})
      @label = label
      @tooltip = tooltip
      @tooltip_id = tooltip_id
      @data = data
    end

    def view_template
      span(class: "ui-nav-lock", role: "link", tabindex: "0",
        aria: { disabled: "true", describedby: @tooltip_id }, data: @data) do
        plain @label
        svg(viewBox: "0 0 24 24", width: "14", height: "14", fill: "none", stroke: "currentColor",
          stroke_width: "2", aria: { hidden: true }) do |icon|
          icon.rect(x: "5", y: "10", width: "14", height: "11", rx: "2")
          icon.path(d: "M8 10V7a4 4 0 0 1 8 0v3")
        end
        span(id: @tooltip_id, role: "tooltip") { @tooltip }
      end
    end
  end
end

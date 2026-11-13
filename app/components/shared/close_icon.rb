module Shared
  class CloseIcon < Base
    def view_template
      svg(viewBox: "0 0 16 16", width: "16", height: "16", fill: "none", stroke: "currentColor",
        stroke_width: "1.5", stroke_linecap: "round", aria: { hidden: true }) do |icon|
        icon.path(d: "M4 4l8 8m0-8-8 8")
      end
    end
  end
end

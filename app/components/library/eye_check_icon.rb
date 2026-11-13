module Library
  class EyeCheckIcon < Shared::Base
    def view_template
      svg(viewBox: "0 0 24 24", width: "20", height: "20", fill: "none", stroke: "currentColor",
        stroke_width: "1.75", stroke_linecap: "round", stroke_linejoin: "round", aria: { hidden: true }) do |icon|
        icon.path(d: "M2 12s3.6-6 10-6 10 6 10 6-3.6 6-10 6-10-6-10-6Z")
        icon.path(d: "m9 12 2 2 4-4")
      end
    end
  end
end

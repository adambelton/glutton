module Library
  class BookmarkMinusIcon < Shared::Base
    def view_template
      svg(viewBox: "0 0 24 24", width: "20", height: "20", fill: "none", stroke: "currentColor",
        stroke_width: "1.75", stroke_linecap: "round", stroke_linejoin: "round", aria: { hidden: true }) do |icon|
        icon.path(d: "M6 4h12a1 1 0 0 1 1 1v16l-7-4-7 4V5a1 1 0 0 1 1-1Z")
        icon.path(d: "M8.5 10.5h7")
      end
    end
  end
end

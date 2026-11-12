module Library
  class NotesIcon < Shared::Base
    def view_template
      svg(viewBox: "0 0 24 24", width: 20, height: 20, fill: "none", stroke: "currentColor",
        stroke_width: "1.75", stroke_linecap: "round", stroke_linejoin: "round", aria: { hidden: true }) do |icon|
        icon.path(d: "M6 3h9l4 4v14H6Z")
        icon.path(d: "M9 11h7m-7 4h7")
      end
    end
  end
end

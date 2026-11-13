module Ratings
  class RatingValueIcon < Shared::Base
    ICON_PATHS = {
      Rating::Values::BRILLIANT => "M9 18h6m-5 4h4m-5-7a6 6 0 1 1 6 0v1H9z",
      Rating::Values::PRETTY_GOOD => "m5 12 4 4L19 6",
      Rating::Values::NOT_FOR_ME => "M7 3h11a2 2 0 0 1 2 2l2 7a2 2 0 0 1-2 2h-5l1 5a2 2 0 0 1-2 2l-7-8m0-10v10m0-10H2v10h5",
      Rating::Values::GARBAGE => "M3 6h18M8 6V3h8v3m3 0-1 15H6L5 6m5 4v7m4-7v7",
      nil => "M8 8a4 4 0 1 1 6 3.5c-1.4.8-2 1.5-2 3.5m0 4h.01"
    }.freeze

    def initialize(value:, size: 20)
      @value, @size = value, size
    end

    def view_template
      svg(viewBox: "0 0 24 24", width: @size, height: @size, fill: "none", stroke: "currentColor",
        stroke_width: "1.75", stroke_linecap: "round", stroke_linejoin: "round", aria: { hidden: true }) do |icon|
        icon.path(d: ICON_PATHS.fetch(@value))
      end
    end
  end
end

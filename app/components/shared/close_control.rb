module Shared
  class CloseControl < Base
    def initialize(label:, class_name:, data:, href: nil, hidden: false)
      @label, @class_name, @data, @href, @hidden = label, class_name, data, href, hidden
    end

    def view_template
      element, attributes = @href.present? ? [ :a, { href: @href } ] : [ :button, { type: :button } ]
      tag(element, **attributes, class: [ "ui-close-control", @class_name ], hidden: @hidden, title: @label,
        aria: { label: @label }, data: @data) do
        span(aria: { hidden: "true" }) { "×" }
      end
    end
  end
end

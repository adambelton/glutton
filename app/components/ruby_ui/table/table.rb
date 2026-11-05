# frozen_string_literal: true

module RubyUI
  class Table < Base
    def initialize(scroll_label:, **attrs)
      @scroll_label = scroll_label
      super(**attrs)
    end

    def view_template(&block)
      div(class: "relative w-full overflow-auto", role: "region", aria: { label: @scroll_label }, tabindex: "0") do
        table(**attrs, &block)
      end
    end

    private

    def default_attrs
      {
        class: "w-full caption-bottom text-sm"
      }
    end
  end
end

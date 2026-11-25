module Shared
  class NavigationTabs < Base
    def initialize(label:, css_class: nil)
      @label, @css_class = label, css_class
    end

    def view_template
      nav(class: [ "ui-navigation-tabs", @css_class ], aria: { label: @label }) { yield }
    end
  end
end

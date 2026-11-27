module Shared
  class HeaderBanner < Base
    def initialize(message:, link_label:, link_path:, class_name: nil, **attrs)
      @message, @link_label, @link_path = message, link_label, link_path
      @class_name, @attrs = class_name, attrs
    end

    def view_template
      aside(class: [ "ui-header-banner", @class_name ], **@attrs) do
        div(class: "ui-header-banner-content") do
          span { @message }
          plain " "
          a(href: @link_path) { @link_label }
        end
      end
    end
  end
end

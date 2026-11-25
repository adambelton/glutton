module Community
  class GluttonIdentity < Shared::Base
    def initialize(class_name:)
      @class_name = class_name
    end

    def view_template
      div(class: @class_name) do
        span(class: "community-member-avatar community-glutton-avatar", aria: { hidden: true })
        strong { t("ui.wordmark") }
      end
    end
  end
end

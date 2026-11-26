module Shared
  class ActionRow < Base
    def initialize(full_width: false, full_width_on_mobile: false)
      @full_width = full_width
      @full_width_on_mobile = full_width_on_mobile
    end

    def view_template(&)
      div(class: [ "ui-actions ui-actions-fixed justify-end", ("ui-actions-full" if @full_width),
        ("ui-actions-mobile-full" if @full_width_on_mobile) ], &)
    end
  end
end

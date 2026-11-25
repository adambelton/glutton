module Community
  class PostBadge < Shared::Base
    def initialize(label:, tooltip: nil, tooltip_id: nil)
      @label, @tooltip, @tooltip_id = label, tooltip, tooltip_id
    end

    def view_template
      span(class: "community-post-tag", tabindex: (0 if @tooltip_id.present?), aria: { describedby: @tooltip_id }) do
        span { @label }
        span(id: @tooltip_id, role: "tooltip") { @tooltip } if @tooltip_id.present?
      end
    end
  end
end

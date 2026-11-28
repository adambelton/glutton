module Community
  class PostCardDetails < Shared::Base
    def initialize(title_id:, below_title: nil, attribution: nil, status: nil)
      @title_id, @below_title, @attribution, @status = title_id, below_title, attribution, status
    end

    def view_template(&title)
      div(class: "community-post-card-details") do
        header(class: "community-post-card-heading") do
          h2(id: @title_id, &title)
          render @below_title if @below_title.present?
          render @attribution if @attribution.present?
        end
        if @status.present?
          footer(class: "muted community-post-card-footer") { render @status }
        end
      end
    end
  end
end

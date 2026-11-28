module Community
  class PostHeading < Shared::Base
    def initialize(title:, badges:, attribution: nil, title_content: nil)
      @title, @badges, @attribution, @title_content = title, badges, attribution, title_content
    end

    def view_template
      header(class: "community-post-heading") do
        h1 { @title_content.present? ? render(@title_content) : plain(@title) }
        render @badges
        render @attribution if @attribution.present?
      end
    end
  end
end

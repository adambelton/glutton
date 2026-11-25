module Community
  class CurationTag < Shared::Base
    def initialize(post_id:, protected_post:, show_tooltips: false)
      @post_id, @protected_post, @show_tooltips = post_id, protected_post, show_tooltips
    end

    def view_template
      div(class: "community-post-tags flex flex-wrap gap-2") do
        badge(:curation, label: t("community.curations.tag"), tooltip: t("community.curations.tag_tooltip"))
        if @protected_post
          badge(:protected, label: t("community.curation_protection.badge"), tooltip: t("community.curation_protection.badge_tooltip"))
        end
      end
    end

    private

    def badge(kind, label:, tooltip:)
      tooltip_id = "post-#{@post_id}-#{kind}-tooltip" if @show_tooltips
      render PostBadge.new(label:, tooltip:, tooltip_id:)
    end
  end
end

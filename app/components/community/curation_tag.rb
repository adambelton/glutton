module Community
  class CurationTag < Shared::Base
    def view_template
      span(class: "community-post-tag") { t("community.curations.tag") }
    end
  end
end

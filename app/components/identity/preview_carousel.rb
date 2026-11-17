module Identity
  class PreviewCarousel < Shared::Base
    def initialize(feature:, labels:)
      @feature, @labels = feature, labels
    end

    def view_template
      section(class: "demo-carousel", aria: { label: t("identity.entry.features.#{@feature}.samples") },
        data: { controller: "landing-examples",
          "landing-examples-position-template-value": t("identity.entry.demo.position", position: "%{position}", count: @labels.size) }) do
        div(class: "demo-browser") do
          @labels.each_with_index do |label, index|
            article(class: "demo-frame", hidden: !index.zero?, aria: { label: }, data: { "landing-examples-target": "panel" }) { yield index }
          end
        end
        nav(class: "demo-controls", hidden: true, aria: { label: t("identity.entry.demo.browse_feature", feature: t("identity.entry.features.#{@feature}.samples")) }, data: { "landing-examples-target": "controls" }) do
          p(class: "sr-only", aria: { live: "polite", atomic: "true" }, data: { "landing-examples-target": "position" }) { t("identity.entry.demo.position", position: 1, count: @labels.size) }
          @labels.each_index do |index|
            render Shared::IconButton.new(variant: :plain, class: "demo-dot", aria: { label: t("identity.entry.demo.select", position: index + 1, count: @labels.size), current: ("true" if index.zero?) },
              data: { "landing-examples-target": "dot", action: "landing-examples#select", index: })
          end
        end
      end
    end
  end
end

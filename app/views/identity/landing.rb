module Views
  module Identity
    class Landing < ::Views::Base
      def initialize(examples:)
        @examples = examples
      end

      def view_template
        render UI::Layout.new(title: t("identity.entry.title")) do
          main(id: "main-content", tabindex: "-1", class: "landing-demo") do
            header(class: "demo-intro") do
              p(class: "preview-eyebrow") { t("identity.entry.eyebrow") }
              h1 { t("identity.entry.title") }
              p { t("identity.entry.demo.description") }
            end
            if @examples.present?
              section(class: "demo-browser", aria: { label: t("identity.entry.demo.label") },
                data: { controller: "landing-examples", action: "mouseenter->landing-examples#stop mouseleave->landing-examples#start focusin->landing-examples#stop focusout->landing-examples#resume visibilitychange@document->landing-examples#start", "landing-examples-position-template-value": t("identity.entry.demo.position", position: "%{position}", count: @examples.size) }) do
                p(class: "demo-disclaimer") { t("identity.entry.demo.disclaimer") }
                @examples.each_with_index do |example, index|
                  article(class: "demo-frame", hidden: index != 0, aria: { label: example.fetch(:film).title }, data: { "landing-examples-target": "panel" }) do
                    render ::Ratings::Form.new(film: example.fetch(:film), value: example.fetch(:rating),
                      expression_texts: t("identity.entry.demo.examples.#{example.fetch(:key)}.expressions"), readonly: true)
                  end
                end
                nav(class: "demo-controls", hidden: true, aria: { label: t("identity.entry.demo.browse") }, data: { "landing-examples-target": "controls" }) do
                  p(class: "sr-only", aria: { live: "polite", atomic: "true" }, data: { "landing-examples-target": "position" }) { t("identity.entry.demo.position", position: 1, count: @examples.size) }
                  @examples.each_index do |index|
                    button(type: "button", class: "demo-dot", aria: { label: t("identity.entry.demo.select", position: index + 1, count: @examples.size), current: ("true" if index.zero?) },
                      data: { "landing-examples-target": "dot", action: "landing-examples#select", index: })
                  end
                  button(type: "button", class: "demo-rotation", aria: { label: t("identity.entry.demo.pause") },
                    data: { "landing-examples-target": "rotation", action: "landing-examples#toggle",
                      "pause-label": t("identity.entry.demo.pause"), "resume-label": t("identity.entry.demo.resume") }) do
                    span(aria: { hidden: "true" }, data: { "landing-examples-target": "rotationIcon" }) { "Ⅱ" }
                  end
                end
              end
            else
              p(class: "preview-empty") { t("identity.entry.empty") }
            end
            section(class: "demo-entry", aria: { label: t("identity.entry.demo.get_started") }) do
              h2 { t("identity.entry.demo.get_started") }
              div(class: "preview-actions") do
                text_link(t("ui.log_in"), new_session_path)
                text_link(t("ui.register"), new_registration_path)
                render UI::ActionButton.new(text: t("identity.entry.try_it_out"), url: guest_session_path)
              end
              p(class: "muted") { t("identity.entry.guest_explanation") }
              p(class: "preview-attribution") do
                a(href: "https://www.themoviedb.org", rel: "noreferrer") { t("identity.entry.attribution") }
                plain " "
                plain t("identity.entry.tmdb_disclaimer")
              end
            end
          end
        end
      end
    end
  end
end

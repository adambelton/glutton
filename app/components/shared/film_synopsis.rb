module Shared
  class FilmSynopsis < Base
    def initialize(text:, id:)
      @text, @id = text, id
    end

    def view_template
      return unless @text.present?

      div(class: "film-synopsis", data: { controller: "film-synopsis", action: "keydown.esc->film-synopsis#collapse",
        film_synopsis_expand_label_value: t("ui.synopsis.expand"), film_synopsis_collapse_label_value: t("ui.synopsis.collapse") }) do
        div(class: "film-synopsis-content") do
          button(type: "button", class: "film-synopsis-toggle", hidden: true,
            aria: { controls: @id, expanded: "false", label: t("ui.synopsis.expand") },
            data: { film_synopsis_target: "toggle", action: "film-synopsis#toggle" }) do
            svg(viewBox: "0 0 24 24", width: 18, height: 18, fill: "none", stroke: "currentColor", stroke_width: 1.75,
              stroke_linecap: "round", stroke_linejoin: "round", aria: { hidden: true }) { |icon| icon.path(d: "m6 9 6 6 6-6") }
          end
          p(id: @id, class: "film-synopsis-text", data: { film_synopsis_target: "text" }) { @text }
        end
      end
    end
  end
end

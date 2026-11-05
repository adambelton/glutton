module Registry
  class AssociationEvidence < UI::Base
    def initialize(association:)
      @association = association
    end

    def view_template
      evaluation = @association.film_quality_eval
      unless evaluation
        p(class: "muted") { t("registry.no_evidence") }
        return
      end
      output = evaluation.output
      quality_id = @association.quality_id.to_s
      context = output.fetch("source").fetch("wikipedia_context", {})
      references = output.fetch("evidence").fetch(quality_id, [])
      paragraphs = context.fetch("source_paragraphs", []).select { |paragraph| references.include?(paragraph.fetch("id")) }
      prefix = "evidence-#{@association.id}"
      details(class: "evidence-disclosure") do
        summary { t("registry.view_evidence", id: evaluation.id) }
        div(class: "evidence-content") do
          p(class: "muted") { t("registry.historical_evidence") }
          support = output.fetch("support")[quality_id]
          p { t("registry.support", value: (support * 100).round) } unless support.nil?
          if paragraphs.any?
            nav(class: "source-links", aria: { label: t("registry.evidence_paragraphs") }) do
              paragraphs.each { |paragraph| a(href: "##{prefix}-#{paragraph.fetch('id')}") { paragraph.fetch("id") } }
            end
          end
          render SourceContext.new(context:, paragraphs:, prefix:, empty_message_key: "registry.no_paragraph_evidence")
        end
      end
    end
  end
end

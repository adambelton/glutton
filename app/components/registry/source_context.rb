module Registry
  class SourceContext < Shared::Base
    def initialize(context:, paragraphs: nil, prefix: "source", empty_message_key: "registry.no_context")
      @context = context
      @paragraphs = paragraphs || context.fetch("source_paragraphs", [])
      @prefix = prefix
      @empty_message_key = empty_message_key
    end

    def view_template
      div(class: "source-attribution") do
        p { t("registry.wikipedia_attribution") }
        div(class: "source-links") do
          external_link(@context["title"].presence || t("registry.article"), @context["article_url"])
          external_link(t("registry.revision", id: @context["revision_id"] || t("registry.not_stored")), @context["revision_url"])
          external_link(t("registry.history"), @context["history_url"])
          license = @context.fetch("license", {})
          external_link(license["name"].presence || t("registry.license"), license["url"])
        end
        p { t("registry.retrieved", at: @context["retrieved_at"].presence || t("registry.not_stored")) }
      end
      @paragraphs.each do |paragraph|
        article(id: "#{@prefix}-#{paragraph.fetch('id')}", class: "source-paragraph") do
          h3 { t("registry.paragraph", id: paragraph.fetch("id"), section: paragraph["section"].presence || t("registry.context")) }
          p { paragraph.fetch("text") }
        end
      end
      p(class: "empty-state") { t(@empty_message_key) } if @paragraphs.empty?
    end

    private

    def external_link(label, url)
      if WikipediaContext.https_url?(url)
        a(href: url, rel: "noreferrer") { label }
      else
        span { label }
      end
    end
  end
end

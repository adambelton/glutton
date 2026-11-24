module Community
  class CurationTextFields < Shared::Base
    def initialize(curation:)
      @curation = curation
    end

    def view_template
      title_field
      description_field
    end

    private

    def title_field
      div(class: "ui-field") do
        label(for: "curation_title") { t("community.curations.title") }
        render RubyUI::Input.new(type: :text, name: "curation[title]", id: "curation_title", class: "ui-input",
          value: @curation.title, maxlength: ::Community::PostCommunityCuration::TITLE_LIMIT, required: true,
          aria: { describedby: "curation_title_hint" })
        p(id: "curation_title_hint", class: "muted") { t("community.curations.title_hint") }
      end
    end

    def description_field
      div(class: "ui-field") do
        label(for: "curation_prompt") { t("community.curations.description") }
        textarea(name: "curation[prompt]", id: "curation_prompt", class: "ui-input", rows: 5,
          maxlength: ::Community::PostCommunityCuration::PROMPT_LIMIT, required: true,
          aria: { describedby: "curation_description_hint" }) { @curation.prompt.to_s }
        p(id: "curation_description_hint", class: "muted") { t("community.curations.description_hint") }
      end
    end
  end
end

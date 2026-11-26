module Views
  module Community
    class EditCuration < ::Views::Base
      def initialize(curation:)
        @curation = curation
      end

      def view_template
        page(title: t("community.curation_editing.title"), class: "community-curation-form") do
          errors(@curation.errors.full_messages)
          editable_attributes = @curation.protected? ? [ :additional_description ] : [ :title, :prompt ]
          baseline = editable_attributes.to_h { |attribute| [ "curation[#{attribute}]", @curation.attribute_in_database(attribute) ] }
          form_with(url: form_path, method: :patch, data: track_form_changes(baseline:)) do
            if @curation.protected?
              protected_fields
            else
              render ::Community::CurationTextFields.new(curation: @curation)
            end
            actions(changed: editable_attributes.any? { |attribute| @curation.will_save_change_to_attribute?(attribute) })
          end
        end
      end

      private

      def form_path
        @curation.protected? ? additional_description_community_curation_path(@curation) : community_curation_path(@curation)
      end

      def protected_fields
        p(id: "protected-curation-explanation", class: "muted") { t("community.curation_protection.editor_explanation") }
        dl(class: "mt-4 space-y-4") do
          original_field(:protected_title, @curation.title)
          original_field(:protected_description, @curation.prompt)
        end
        div(class: "ui-field") do
          label(for: "curation_additional_description") { t("community.curation_protection.additional_description") }
          textarea(id: "curation_additional_description", name: "curation[additional_description]", class: "ui-input",
            aria: { describedby: "protected-curation-explanation" }, maxlength: ::Community::PostCommunityCuration::PROMPT_LIMIT) { @curation.additional_description.to_s }
        end
      end

      def original_field(label, value)
        div do
          dt(class: "muted font-medium") { t("community.curation_protection.#{label}") }
          dd { span(class: "community-curation-prompt") { value } }
        end
      end

      def actions(changed:)
        div(class: "ui-actions ui-actions-fixed ui-actions-mobile-full justify-end") do
          render RubyUI::Link.new(href: community_curation_path(@curation), variant: :ghost, class: "ui-action-button") { t("community.curations.cancel") }
          render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button", disabled: !changed,
            data: { unchanged_form_target: "save" }) { t("community.curation_editing.save") }
        end
      end
    end
  end
end

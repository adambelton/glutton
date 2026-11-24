module Views
  module Community
    class EditCuration < ::Views::Base
      def initialize(curation:)
        @curation = curation
      end

      def view_template
        page(title: t("community.curation_editing.title"), class: "community-curation-form",
          back_to: community_curation_path(@curation), back_label: t("community.curations.back_to_curation")) do
          errors(@curation.errors.full_messages)
          form_with(url: community_curation_path(@curation), method: :patch) do
            render ::Community::CurationTextFields.new(curation: @curation)
            submit(t("community.curation_editing.save"))
          end
        end
      end
    end
  end
end

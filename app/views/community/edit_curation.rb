module Views
  module Community
    class EditCuration < ::Views::Base
      def initialize(curation:)
        @curation = curation
      end

      def view_template
        page(title: t("community.curation_editing.title"), narrow: true) do
          errors(@curation.errors.full_messages)
          form_with(url: community_curation_path(@curation), method: :patch) do
            render ::Community::CurationTextFields.new(curation: @curation)
            div(class: "ui-actions community-curation-actions") do
              submit(t("community.curation_editing.save"))
              text_link(t("community.curations.cancel"), community_curation_path(@curation))
            end
          end
        end
      end
    end
  end
end

module Views
  module Community
    class NewCuration < ::Views::Base
      def initialize(curation:, films:, reference_film_ids:, reference_comments:)
        @curation = curation
        @films = films
        @reference_film_ids = reference_film_ids
        @reference_comments = reference_comments
      end

      def view_template
        page(title: t("community.curations.create"), class: "community-curation-form",
          back_to: community_path, back_label: t("community.curations.back")) do
          errors(@curation.errors.full_messages)
          form_with(url: community_curations_path) do
            render ::Community::CurationTextFields.new(curation: @curation)
            render ::Community::CurationFilmPicker.new(films: @films, selected_film_ids: @reference_film_ids,
              comments: @reference_comments, heading: t("community.curations.reference_films"),
              hint: t("community.curations.reference_hint"), field_prefix: "curation_reference",
              film_ids_name: "curation[reference_film_ids]", comments_name: "curation[reference_comments]")
            submit(t("community.curations.publish"))
          end
        end
      end
    end
  end
end

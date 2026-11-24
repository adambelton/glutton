module Views
  module Community
    class NewCurationResponse < ::Views::Base
      def initialize(curation:, films:, film_ids: [], comments: {})
        @curation, @films, @film_ids, @comments = curation, films, film_ids, comments
      end

      def view_template
        page(title: t("community.curation_responses.title", title: @curation.title), narrow: true,
          back_to: community_curation_path(@curation), back_label: t("community.curation_responses.back")) do
          errors(@curation.errors.full_messages)
          form_with(url: community_curation_response_path(@curation)) do
            render ::Community::CurationFilmPicker.new(films: @films, selected_film_ids: @film_ids,
              comments: @comments, heading: t("community.curation_responses.films"),
              limit: ::Community::PostCommunityCuration::RESPONSE_LIMIT, field_prefix: "curation_response",
              film_ids_name: "response[film_ids]", comments_name: "response[comments]")
            submit(t("community.curation_responses.publish"))
          end
        end
      end
    end
  end
end

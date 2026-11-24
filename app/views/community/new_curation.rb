module Views
  module Community
    class NewCuration < ::Views::Base
      def initialize(curation:, films:, reference_film_ids:, reference_comments:)
        @curation = curation
        @films = films
        @selected_films = films.index_by(&:id).values_at(*reference_film_ids.uniq).compact
        @reference_comments = reference_comments
      end

      def view_template
        page(title: t("community.curations.create"), narrow: true) do
          errors(@curation.errors.full_messages)
          form_with(url: community_curations_path) do
            title_field
            description_field
            reference_picker
            div(class: "ui-actions community-curation-actions") do
              submit(t("community.curations.publish"))
              text_link(t("community.curations.back"), community_path)
            end
          end
        end
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

      def reference_picker
        fieldset(class: "community-reference-picker", data: { controller: "curation-reference-picker" }) do
          legend do
            plain t("community.curations.reference_films")
            plain " "
            span(id: "curation_reference_hint", class: "muted") do
              t("community.curations.reference_hint", count: ::Community::PostCommunityCuration::REFERENCE_LIMIT)
            end
          end
          search_label = t("community.curations.search_watched")
          render RubyUI::Input.new(type: :search, id: "curation_reference_search", class: "ui-input", autocomplete: "off",
            placeholder: search_label, aria: { label: search_label, describedby: "curation_reference_hint" },
            data: { curation_reference_picker_target: "search",
              action: "input->curation-reference-picker#filter keydown.enter->curation-reference-picker#filter:prevent" })
          ul(class: "community-reference-films", hidden: true, data: { curation_reference_picker_target: "results" }) do
            @films.each { |film| reference_option(film) }
          end
          p(hidden: true, role: "status", data: { curation_reference_picker_target: "empty" }) { t("community.curations.no_matches") }
          section(hidden: @selected_films.empty?, data: { curation_reference_picker_target: "selectedSection" }) do
            h2 { t("community.curations.selected_films") }
            ul(class: "community-selected-films", data: { curation_reference_picker_target: "selected" }) do
              @selected_films.each { |film| selected_film(film, body: @reference_comments[film.id]) }
            end
          end
        end
      end

      def reference_option(film)
        title = film_title(film)
        li(data: { film_id: film.id, film_title: title, curation_reference_picker_target: "option" }) do
          span { title }
          button(type: :button, class: "ui-link", aria: { label: t("community.curations.add_film", title:) },
            data: { action: "curation-reference-picker#add" }) { t("community.curations.add") }
          template { selected_film(film) }
        end
      end

      def selected_film(film, body: nil)
        title = film_title(film)
        li(data: { film_id: film.id }) do
          input(type: :hidden, name: "curation[reference_film_ids][]", value: film.id)
          div(class: "community-selected-film-header") do
            span { title }
            button(type: :button, class: "ui-link", aria: { label: t("community.curations.remove_film", title:) },
              data: { action: "curation-reference-picker#remove" }) { t("community.curations.remove") }
          end
          div(class: "community-selected-film-editor") do
            render ::Registry::FilmPoster.new(film:)
            textarea(name: "curation[reference_comments][#{film.id}]", class: "ui-input", rows: 2,
              placeholder: t("community.curations.comment"),
              aria: { label: t("community.curations.comment_for_film", title:) }) { body.to_s }
          end
        end
      end

      def film_title(film)
        return film.title unless film.release_date.present?

        t("community.curations.film_with_year", title: film.title, year: film.release_date.year)
      end
    end
  end
end

module Community
  class CurationFilmPicker < Shared::Base
    def initialize(films:, selected_film_ids:, comments:, heading:, limit:, field_prefix:, film_ids_name:, comments_name:)
      @films = films
      @selected_films = films.index_by(&:id).values_at(*selected_film_ids.uniq).compact
      @comments = comments
      @heading, @limit = heading, limit
      @field_prefix, @film_ids_name, @comments_name = field_prefix, film_ids_name, comments_name
    end

    def view_template
      fieldset(class: "community-reference-picker", data: { controller: "curation-film-picker" }) do
        legend do
          plain @heading
          plain " "
          span(id: hint_id, class: "muted") do
            t("community.curations.reference_hint", count: @limit)
          end
        end
        search_label = t("community.curations.search_watched")
        render RubyUI::Input.new(type: :search, id: "#{@field_prefix}_search", class: "ui-input", autocomplete: "off",
          placeholder: search_label, aria: { label: search_label, describedby: hint_id },
          data: { curation_film_picker_target: "search",
            action: "input->curation-film-picker#filter keydown.enter->curation-film-picker#filter:prevent" })
        ul(class: "community-reference-films", hidden: true, data: { curation_film_picker_target: "results" }) do
          @films.each { |film| film_option(film) }
        end
        p(hidden: true, role: "status", data: { curation_film_picker_target: "empty" }) { t("community.curations.no_matches") }
        section(hidden: @selected_films.empty?, data: { curation_film_picker_target: "selectedSection" }) do
          h2 { t("community.curations.selected_films") }
          ul(class: "community-selected-films", data: { curation_film_picker_target: "selected" }) do
            @selected_films.each { |film| selected_film(film, body: @comments[film.id]) }
          end
        end
      end
    end

    private

    def hint_id
      "#{@field_prefix}_hint"
    end

    def film_option(film)
      title = film_title(film)
      li(data: { film_id: film.id, film_title: title, curation_film_picker_target: "option" }) do
        span { title }
        button(type: :button, class: "ui-link", aria: { label: t("community.curations.add_film", title:) },
          data: { action: "curation-film-picker#add" }) { t("community.curations.add") }
        template { selected_film(film) }
      end
    end

    def selected_film(film, body: nil)
      title = film_title(film)
      li(data: { film_id: film.id }) do
        input(type: :hidden, name: "#{@film_ids_name}[]", value: film.id)
        div(class: "community-selected-film-header") do
          span { title }
          button(type: :button, class: "ui-link", aria: { label: t("community.curations.remove_film", title:) },
            data: { action: "curation-film-picker#remove" }) { t("community.curations.remove") }
        end
        div(class: "community-selected-film-editor") do
          render ::Registry::FilmPoster.new(film:)
          textarea(name: "#{@comments_name}[#{film.id}]", class: "ui-input", rows: 2,
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

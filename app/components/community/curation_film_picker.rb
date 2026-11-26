module Community
  class CurationFilmPicker < Shared::Base
    def initialize(films:, selected_film_ids:, comments:, heading:, field_prefix:, film_ids_name:, comments_name:,
      search_films: films, saved_film_ids: [], hint: nil, published_comments: {}, divide_selected_films: false, in_dialog: false)
      @search_films = search_films
      @saved_film_ids = saved_film_ids
      @selected_films = films.index_by(&:id).values_at(*selected_film_ids.uniq).compact
      @comments = comments
      @published_comments = published_comments
      @divide_selected_films = divide_selected_films
      @in_dialog = in_dialog
      @heading, @hint = heading, hint
      @field_prefix, @film_ids_name, @comments_name = field_prefix, film_ids_name, comments_name
    end

    def view_template
      fieldset(class: "community-reference-picker", data: { controller: "curation-film-picker",
        action: ("resize@window->curation-film-picker#fitDropdown scroll@document->curation-film-picker#fitDropdown:capture" if @in_dialog),
        curation_film_picker_page_label_value: t("ui.search.pagination.page", number: "{number}", total: "{total}"),
        curation_film_picker_saved_ids_value: @saved_film_ids.map(&:to_s).to_json }) do
        legend do
          plain @heading
          if @hint.present?
            plain " "
            span(id: hint_id, class: "muted") { @hint }
          end
        end
        search
        section(hidden: @selected_films.empty?, data: { curation_film_picker_target: "selectedSection" }) do
          h2 { t("community.curations.selected_films") }
          p(id: "#{@field_prefix}_comment_limit", class: "muted") { t("community.comment_limit", count: CommentContent::BODY_LIMIT) }
          ul(class: [ "community-selected-films", ("ui-divided-list" if @divide_selected_films) ],
            data: { curation_film_picker_target: "selected" }) do
            @selected_films.each { |film| selected_film(film) }
          end
        end
        if @saved_film_ids.any?
          p(class: "muted", role: "status", hidden: (@saved_film_ids - @selected_films.map(&:id)).empty?,
            data: { curation_film_picker_target: "withdrawal" }) { t("community.curation_endorsements.withdrawal") }
        end
      end
    end

    private

    def hint_id
      "#{@field_prefix}_hint"
    end

    def search
      search_label = t("community.curations.search_watched")
      results_id = "#{@field_prefix}_results"
      div(class: "relative", data: { action: "focusout->curation-film-picker#dismissOutside" }) do
        render Shared::CollectionSearchField.new(input_id: "#{@field_prefix}_search", label: search_label, controls: results_id,
          description_id: (hint_id if @hint.present?),
          input_data: { curation_film_picker_target: "search",
            action: "input->curation-film-picker#searchChanged focus->curation-film-picker#filter keydown.enter->curation-film-picker#filter:prevent keydown.esc->curation-film-picker#dismiss" },
          clear_data: { curation_film_picker_target: "clear", action: "curation-film-picker#clear" })
        render Shared::FilmSearchDropdown.new(id: results_id, hidden: true, popover: ("manual" if @in_dialog),
          data: { curation_film_picker_target: "results", action: "keydown.esc->curation-film-picker#dismiss" }) do
          render Shared::FilmSearchResultsPanel.new(empty_message: t("community.curations.no_matches"),
            empty_attributes: { hidden: true, data: { curation_film_picker_target: "empty" } }) do
            @search_films.each { |film| film_option(film) }
          end
          pagination
        end
      end
    end

    def pagination
      render Shared::FilmSearchPagination.new(page: 1, total: 1,
        previous: { hidden: true, data: { curation_film_picker_target: "previous", action: "curation-film-picker#previousPage" } },
        next_page: { hidden: true, data: { curation_film_picker_target: "next", action: "curation-film-picker#nextPage" } },
        page_attributes: { aria: { live: "polite" }, data: { curation_film_picker_target: "page" } })
    end

    def film_option(film)
      title = film_label(film)
      poster = ::Registry::FilmPoster.new(film:, placeholder: :wordmark)
      render Shared::FilmSearchResultRow.new(title: film.title, release_date: film.release_date, poster:,
        data: { film_id: film.id, film_title: title, curation_film_picker_target: "option" }) do
        render Shared::PrimaryButton.new(type: :button, size: :sm, aria: { label: t("community.curations.add_film", title:) },
          data: { action: "curation-film-picker#add" }) { t("community.curations.add") }
        template { selected_film(film) }
      end
    end

    def selected_film(film)
      title = film_label(film)
      comment = @published_comments[film.id]
      li(data: { film_id: film.id }) do
        input(type: :hidden, name: "#{@film_ids_name}[]", value: film.id)
        div(class: "community-selected-film-header") do
          span { render ::Registry::FilmTitle.new(film:) }
          div(class: "community-comment-actions") do
            if comment.present?
              a(href: community_post_path(comment.post_id, reply: comment.id, replies: 1, anchor: "comment-#{comment.id}"),
                aria: { label: t("community.curation_endorsements.view_comment_for_film", title:) }, data: { turbo_frame: "_top" }) do
                t("community.curation_endorsements.view_comment")
              end
            end
            button(type: :button, aria: { label: t("community.curations.remove_film", title:) },
              data: { action: "curation-film-picker#remove" }) { t("community.curations.remove") }
          end
        end
        div(class: "community-selected-film-editor") do
          render ::Registry::FilmPoster.new(film:)
          if comment.present?
            div(class: "community-published-comment space-y-1") do
              p(class: "muted font-medium") { t("community.curation_endorsements.published_comment") }
              p(class: "community-curation-prompt") { comment.content.body }
            end
          else
            textarea(name: "#{@comments_name}[#{film.id}]", class: "ui-input", rows: 2, maxlength: CommentContent::BODY_LIMIT,
              placeholder: t("community.curations.comment"),
              aria: { label: t("community.curations.comment_for_film", title:), describedby: "#{@field_prefix}_comment_limit" }) { @comments[film.id].to_s }
          end
        end
      end
    end

    def film_label(film)
      return film.title unless film.release_date.present?

      t("community.curations.film_with_year", title: film.title, year: film.release_date.year)
    end
  end
end

module Views
  module Library
    class Browse < ::Views::Base
      def initialize(view:, page:, page_number:)
        @view, @page, @page_number = view, page, page_number
      end

      def view_template
        page(title: t("library.browser.title"), class: "library-page") do
          form_with(url: library_path, method: :get, class: "library-filter", data: { controller: "library-view" }) do
            label(for: "view") { t("library.browser.view") }
            render RubyUI::NativeSelect.new(name: "view", id: "view", class: "ui-select", data: { action: "change->library-view#change" }) do
              ::Library::Browse::Views::ALL.each do |view|
                render RubyUI::NativeSelectOption.new(value: view, selected: @view == view) { t("library.browser.views.#{view}") }
              end
            end
          end
          h2 { t("library.browser.views.#{@view}") }
          if @page.entries.empty?
            p(class: "ui-empty") { t("library.browser.empty.#{@view}") }
          else
            ul(class: "library-films") do
              @page.entries.each do |library_film|
                li(class: "library-film") do
                  div do
                    h3 { text_link(library_film.film.title, library_film_path(library_film)) }
                    p { t("library.browser.released", year: library_film.film.release_date.year) } if library_film.film.release_date
                  end
                  if @view == ::Library::Browse::Views::WATCHED
                    div(class: "library-rating") do
                      if @page.rated_film_ids.include?(library_film.film_id)
                        p { t("library.browser.rated") }
                        text_link(t("library.browser.edit_rating"), edit_rating_path(film_id: library_film.film_id), aria: { label: t("library.browser.edit_film_rating", title: library_film.film.title) })
                      else
                        p { t("library.browser.awaiting_rating") }
                        text_link(t("library.browser.rate"), new_rating_path(film_id: library_film.film_id), aria: { label: t("library.browser.rate_film", title: library_film.film.title) })
                      end
                    end
                  end
                end
              end
            end
          end
          nav(class: "library-pagination", aria: { label: t("library.browser.pagination") }) do
            text_link(t("library.browser.previous"), library_path(view: @view, page: @page_number - 1)) if @page_number > 1
            span { t("library.browser.page", number: @page_number) }
            text_link(t("library.browser.next"), library_path(view: @view, page: @page_number + 1)) if @page.next_page
          end
        end
      end
    end
  end
end

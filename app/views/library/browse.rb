module Views
  module Library
    class Browse < ::Views::Base
      def initialize(view:, page:, page_number:, ratings:)
        @view, @page, @page_number, @ratings = view, page, page_number, ratings
      end

      def view_template
        page(title: t("library.browser.title"), class: "library-page", heading_outside_card: true,
          heading_action: ::Library::FilmSearchForm.new(dropdown: true)) do
          collection_navigation
          h2(class: "sr-only") { t("library.browser.views.#{@view}") }
          if @page.entries.empty?
            p(class: "ui-empty") { t("library.browser.empty.#{@view}") }
          else
            ul(class: "library-films") do
              @page.entries.each do |library_film|
                li(class: "library-film") do
                  film = library_film.film
                  render ::Registry::FilmPoster.new(film:)
                  render ::Library::LibraryFilmCardControls.new(library_film:)
                  h3 { render ::Registry::FilmTitle.new(film:) }
                end
              end
            end
          end
          nav(class: "library-pagination", aria: { label: t("library.browser.pagination") }) do
            text_link(t("library.browser.previous"), library_path(view: @view, page: @page_number - 1, ratings: @ratings.presence)) if @page_number > 1
            span { t("library.browser.page", number: @page_number) }
            text_link(t("library.browser.next"), library_path(view: @view, page: @page_number + 1, ratings: @ratings.presence)) if @page.next_page
          end
        end
      end

      private

      def watched_view?
        @view == ::Library::CollectionManagement::Browse::Views::WATCHED
      end

      def collection_navigation
        div(class: "library-collection-navigation") do
          nav(class: "library-tabs", aria: { label: t("library.browser.view") }) do
            ::Library::CollectionManagement::Browse::Views::ALL.each do |view|
              a(href: library_path(view:), aria: { current: ("page" if @view == view) }) { t("library.browser.views.#{view}") }
            end
          end
          rating_filters if watched_view?
        end
      end

      def rating_filters
        nav(class: "library-rating-filters", aria: { label: t("library.browser.rating_filters") }) do
          ::Library::CollectionManagement::Browse::RATING_FILTERS.each do |rating|
            selected = @ratings.include?(rating)
            next_ratings = selected ? @ratings - [ rating ] : @ratings + [ rating ]
            unrated = rating == ::Library::CollectionManagement::Browse::UNRATED
            label = unrated ? t("library.browser.unrated") : t("ratings.values.#{rating}")
            a(href: library_path(view: @view, ratings: next_ratings.presence),
              data: { selected: ("true" if selected) }, aria: { label: (t("library.browser.selected_rating", rating: label) if selected) }) do
              render ::Ratings::RatingValueIcon.new(value: (rating unless unrated), size: 14)
              plain label
            end
          end
          clear_rating_filters
        end
      end

      def clear_rating_filters
        label = t("library.browser.clear_rating_filters")
        enabled = @ratings.present?
        form_with(url: library_path, method: :get, class: "library-clear-filters-form") do
          input(type: "hidden", name: "view", value: @view)
          render Shared::IconButton.new(type: :submit, variant: :plain, class: "library-clear-filters",
            disabled: !enabled, aria: { label: }, data: { tooltip: (label if enabled) }) { render Shared::CloseIcon.new }
        end
      end
    end
  end
end

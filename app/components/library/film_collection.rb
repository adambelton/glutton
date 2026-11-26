module Library
  class FilmCollection < Shared::Base
    def initialize(view:, page:, page_number:, ratings:, query: "", preview: false)
      @view, @page, @page_number, @ratings, @query, @preview = view, page, page_number, ratings, query, preview
    end

    def view_template(&block)
      collection_navigation
      h2(class: "sr-only") { t("library.browser.views.#{@view}") }
      if @page.entries.empty?
        p(class: "ui-empty") { t(@query.present? ? "library.browser.no_matches" : "library.browser.empty.#{@view}") }
      else
        render ::Library::FilmGrid.new(entries: @page.entries, link_titles: !@preview), &block
      end
      nav(class: "library-pagination", aria: { label: t("library.browser.pagination") }) do
        pagination_link(:previous, @page_number - 1) if @page_number > 1
        span { t("library.browser.page", number: @page_number) }
        pagination_link(:next, @page_number + 1) if @page.next_page
      end
    end

    private

    def pagination_link(direction, number)
      if @preview
        span(class: "ui-link") { t("library.browser.#{direction}") }
      else
        text_link(t("library.browser.#{direction}"), library_path(view: @view, page: number, ratings: @ratings.presence, q: @query.presence))
      end
    end

    def watched_view?
      @view == ::Library::CollectionManagement::BrowseFilmCollection::Views::WATCHED
    end

    def collection_navigation
      div(class: "library-collection-navigation") do
        render Shared::NavigationTabs.new(label: t("library.browser.view"), css_class: "library-tabs") do
          ::Library::CollectionManagement::BrowseFilmCollection::Views::ALL.each do |view|
            if @preview
              button(type: "button", value: view, aria: { current: ("page" if @view == view) }, data: { action: "library-preview#changeView" }) { t("library.browser.views.#{view}") }
            else
              a(href: library_path(view:, q: @query.presence), aria: { current: ("page" if @view == view) }) { t("library.browser.views.#{view}") }
            end
          end
        end
        rating_filters if watched_view?
      end
    end

    def rating_filters
      nav(class: "library-rating-filters", aria: { label: t("library.browser.rating_filters") }) do
        ::Library::CollectionManagement::BrowseFilmCollection::RATING_FILTERS.each do |rating|
          selected = @ratings.include?(rating)
          next_ratings = selected ? @ratings - [ rating ] : @ratings + [ rating ]
          unrated = rating == ::Library::CollectionManagement::BrowseFilmCollection::UNRATED
          label = unrated ? t("library.browser.unrated") : t("ratings.values.#{rating}")
          if @preview
            button(type: "button", value: rating, data: { selected: ("true" if selected), action: "library-preview#filter", library_preview_target: "rating" },
              aria: { label:, pressed: selected.to_s }) do
              render ::Ratings::RatingValueIcon.new(value: (rating unless unrated), size: 14)
              span(class: "library-rating-filter-label") { label }
            end
          else
            a(href: library_path(view: @view, ratings: next_ratings.presence, q: @query.presence),
              data: { selected: ("true" if selected) }, aria: { label: (selected ? t("library.browser.selected_rating", rating: label) : label) }) do
              render ::Ratings::RatingValueIcon.new(value: (rating unless unrated), size: 14)
              span(class: "library-rating-filter-label") { label }
            end
          end
        end
        clear_rating_filters
      end
    end

    def clear_rating_filters
      label = t("library.browser.clear_rating_filters")
      enabled = @ratings.present?
      if @preview
        render Shared::IconButton.new(variant: :plain, class: "library-clear-filters", disabled: !enabled, aria: { label: },
          data: { action: "library-preview#clear", library_preview_target: "clear" }) { render Shared::CloseIcon.new }
        return
      end

      form_with(url: library_path, method: :get, class: "library-clear-filters-form") do
        input(type: "hidden", name: "view", value: @view)
        input(type: "hidden", name: "q", value: @query) if @query.present?
        render Shared::IconButton.new(type: :submit, variant: :plain, class: "library-clear-filters",
          disabled: !enabled, aria: { label: }, data: { tooltip: (label if enabled) }) { render Shared::CloseIcon.new }
      end
    end
  end
end

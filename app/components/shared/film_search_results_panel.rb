module Shared
  class FilmSearchResultsPanel < Base
    def initialize(error: nil, empty_message: nil, empty_attributes: nil)
      @error, @empty_message, @empty_attributes = error, empty_message, empty_attributes
    end

    def view_template
      h2(class: "film-search-results-heading") { t("ui.film_search_results") }
      div(class: "film-search-content", data: { controller: "tmdb-film-search-tooltip",
        action: "pointerover->tmdb-film-search-tooltip#show pointerout->tmdb-film-search-tooltip#leave focusin->tmdb-film-search-tooltip#show " \
          "focusout->tmdb-film-search-tooltip#leave scroll->tmdb-film-search-tooltip#hide scroll@window->tmdb-film-search-tooltip#hide " \
          "resize@window->tmdb-film-search-tooltip#hide" }) do
        if @error.present?
          p(role: "alert") { @error }
        else
          ul(class: "film-search-results ui-divided-list") { yield } if @empty_message.blank? || @empty_attributes.present?
          p(role: "status", **(@empty_attributes || {})) { @empty_message } if @empty_message.present?
        end
      end
    end
  end
end

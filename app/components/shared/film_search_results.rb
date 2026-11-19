module Shared
  class FilmSearchResults < Base
    def initialize(error: nil, empty_message: nil)
      @error, @empty_message = error, empty_message
    end

    def view_template
      h2(class: "film-search-results-heading") { t("ui.film_search_results") }
      div(class: "film-search-content") do
        if @error.present?
          p(role: "alert") { @error }
        elsif @empty_message.present?
          p(role: "status") { @empty_message }
        else
          ul(class: "film-search-results") { yield }
        end
      end
    end
  end
end

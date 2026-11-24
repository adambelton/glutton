module Shared
  class TmdbFilmSearchResultRow < Base
    def initialize(candidate:, status: nil)
      @candidate, @status = candidate, status
    end

    def view_template
      title = @candidate.fetch(:title)
      li(data: { tmdb_film_id: @candidate.fetch(:tmdb_id) }) do
        render ::Registry::FilmPoster.new(title:, path: @candidate.fetch(:poster_path), placeholder: :wordmark)
        div(class: "film-search-result-body") do
          div(class: "film-search-result-details") do
            h3 do
              a(href: "https://www.themoviedb.org/movie/#{@candidate.fetch(:tmdb_id)}",
                class: "film-search-title-link", target: "_blank", rel: "noopener noreferrer",
                title: t("ui.open_film_on_tmdb")) do
                render ::Registry::FilmTitle.new(title:, release_date: @candidate.fetch(:release_date))
              end
            end
            overview = @candidate.fetch(:overview)
            p(class: "film-search-overview") { overview } if overview.present?
            p { @status } if @status.present?
          end
          div(class: "film-search-actions") { yield } if block_given?
        end
      end
    end
  end
end

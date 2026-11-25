module Shared
  class TmdbFilmSearchResultRow < Base
    def initialize(candidate:, status: nil, icon_actions: false)
      @candidate, @status, @icon_actions = candidate, status, icon_actions
    end

    def view_template(&actions)
      title = @candidate.fetch(:title)
      tmdb_id = @candidate.fetch(:tmdb_id)
      poster = ::Registry::FilmPoster.new(title:, path: @candidate.fetch(:poster_path), placeholder: :wordmark)
      render FilmSearchResultRow.new(title:, release_date: @candidate.fetch(:release_date), poster:,
        data: { tmdb_film_id: tmdb_id }, overview: @candidate.fetch(:overview), status: @status, icon_actions: @icon_actions,
        link: { href: "https://www.themoviedb.org/movie/#{tmdb_id}", class: "film-search-title-link",
          target: "_blank", rel: "noopener noreferrer", title: t("ui.open_film_on_tmdb") }), &actions
    end
  end
end

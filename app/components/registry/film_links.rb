module Registry
  class FilmLinks < Shared::Base
    def initialize(film:)
      @film = film
    end

    def view_template
      div(class: "rating-film-links") do
        if @film.tmdb_id.present?
          source_link(t("registry.film_presentation.tmdb"), "https://www.themoviedb.org/movie/#{@film.tmdb_id}")
        end
        page_id = @film.wikipedia_context["page_id"]
        if page_id.is_a?(Integer) && page_id.positive?
          source_link(t("registry.film_presentation.wikipedia"), "https://en.wikipedia.org/w/index.php?curid=#{page_id}")
        end
      end
    end

    private

    def source_link(label, url)
      a(href: url, class: "rating-film-link", target: "_blank", rel: "noopener noreferrer") { label }
    end
  end
end

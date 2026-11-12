module Library
  class RatingPrompt < Shared::Base
    def initialize(library_film:)
      @library_film = library_film
    end

    def view_template
      if @library_film.can_rate?
        text_link(t("library.browser.rate"), new_rating_path(film_id: @library_film.film_id), aria: { label: t("library.browser.rate_film", title: @library_film.film.title) })
      elsif @library_film.can_edit_rating?
        text_link(t("library.browser.edit_rating"), edit_rating_path(film_id: @library_film.film_id), aria: { label: t("library.browser.edit_film_rating", title: @library_film.film.title) })
      end
    end
  end
end

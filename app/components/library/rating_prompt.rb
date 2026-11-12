module Library
  class RatingPrompt < Shared::Base
    def initialize(library_film:)
      @library_film = library_film
    end

    def view_template
      title = @library_film.film.title
      film_id = @library_film.film_id
      if @library_film.can_edit_rating?
        rating = @library_film.current_rating
        value = t("ratings.values.#{rating.value}")
        rating_link(edit_rating_path(film_id:), label: t("library.browser.edit_film_rating", title:),
          tooltip: t("library.browser.edit_rating", value:), rating:)
      elsif @library_film.can_rate?
        rating_link(new_rating_path(film_id:), label: t("library.browser.rate_film", title:), tooltip: t("library.browser.rate"))
      end
    end

    private

    def rating_link(url, label:, tooltip:, rating: nil)
      has_notes = rating&.notes.present?
      description = t(has_notes ? "library.browser.notes_present" : "library.browser.notes_absent")
      a(href: url, class: "library-rating-icon", aria: { label:, description: }, data: { tooltip: }) do
        render Ratings::ValueIcon.new(value: rating&.value)
        span(class: "library-rating-notes-badge", aria: { hidden: true }) { render NotesIcon.new } if has_notes
      end
    end
  end
end

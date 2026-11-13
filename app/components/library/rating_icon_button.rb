module Library
  class RatingIconButton < Shared::Base
    def initialize(library_film:)
      @library_film = library_film
    end

    def view_template
      title = @library_film.film.title
      film_id = @library_film.film_id
      if @library_film.can_edit_rating?
        rating = @library_film.current_rating
        value = t("ratings.values.#{rating.value}")
        rating_button(edit_rating_path, film_id:, label: t("library.browser.edit_film_rating", title:),
          tooltip: t("library.browser.edit_rating", value:), rating:)
      elsif @library_film.can_rate?
        rating_button(new_rating_path, film_id:, label: t("library.browser.rate_film", title:), tooltip: t("library.browser.rate", value: t("library.browser.unrated")))
      end
    end

    private

    def rating_button(url, film_id:, label:, tooltip:, rating: nil)
      has_notes = rating&.notes.present?
      description = t(has_notes ? "library.browser.notes_present" : "library.browser.notes_absent")
      form_with(url:, method: :get, class: "ui-action-form") do
        input(type: "hidden", name: "film_id", value: film_id.to_s)
        render Shared::IconButton.new(type: :submit, variant: :ghost, size: :xl, class: "ui-action-button library-rating-icon",
          aria: { label:, description: }, data: { tooltip: }) do
          render Ratings::RatingValueIcon.new(value: rating&.value)
          span(class: "library-rating-notes-badge", aria: { hidden: true }) { render NotesIcon.new } if has_notes
        end
      end
    end
  end
end

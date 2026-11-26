module Library
  class RatingIconButton < Shared::Base
    def initialize(library_film:, readonly: false, value: nil, notes: false)
      @library_film, @readonly, @value, @notes = library_film, readonly, value, notes
    end

    def view_template
      if @readonly
        rating_button(value: @value, notes: @notes)
      elsif @library_film.can_edit_rating?
        rating = @library_film.current_rating
        rating_button(url: edit_rating_path, value: rating.value, notes: rating.notes.present?)
      elsif @library_film.can_rate?
        rating_button(url: new_rating_path)
      end
    end

    private

    def rating_button(url: nil, value: nil, notes: false)
      title = @library_film.film.title
      label = t(value.present? ? "library.browser.edit_film_rating" : "library.browser.rate_film", title:)
      tooltip = if value.present?
        t("library.browser.edit_rating", value: t("ratings.values.#{value}"))
      else
        t("library.browser.rate", value: t("library.browser.unrated"))
      end
      description = t(notes ? "library.browser.notes_present" : "library.browser.notes_absent")
      render CardAction.new(url:, method: :get, params: { film_id: @library_film.film_id }, label:, tooltip:, film_title: title, readonly: @readonly,
        class: "ui-action-button library-rating-icon", aria: { label:, description: }) do
        render RatingIndicator.new(value:, notes:)
      end
    end
  end
end

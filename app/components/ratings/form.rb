module Ratings
  class Form < Shared::Base
    def initialize(film:, rating_film_id: nil, method: :post, value: nil, expression_texts: [], expression_draft: nil, previous_rating_id: nil, errors: nil, readonly: false, dismissible: false, targeted: false)
      @film, @rating_film_id, @method, @value = film, rating_film_id, method, value
      @expression_texts, @previous_rating_id, @errors, @readonly = expression_texts, previous_rating_id, errors, readonly
      @expression_draft = expression_draft
      @dismissible, @targeted = dismissible, targeted
      @prefix = readonly ? "example-#{film.tmdb_id}-" : ""
    end

    def view_template
      div(class: "rating-interface") do
        errors_section
        if @readonly
          div(class: "rating-workspace") { workspace }
        else
          form_with(url: rating_path, method: @method, id: "rating-form", class: "rating-workspace") do
            input(type: "hidden", name: "rating_film_id", value: @rating_film_id)
            input(type: "hidden", name: "targeted", value: "1") if @targeted
            input(type: "hidden", name: "previous_rating_id", value: @previous_rating_id) if @method == :patch
            workspace
          end
          div(class: "rating-actions") do
            render RubyUI::Button.new(type: :submit, form: "rating-form", class: "ui-submit") { t("ratings.browser.save") }
            if @dismissible
              render Shared::ActionButton.new(text: t("ratings.browser.dismiss"), url: dismiss_rating_path, params: { rating_film_id: @rating_film_id })
            end
          end
        end
      end
    end

    private

    def workspace
      div(class: "rating-film-info") do
        div(class: "rating-film-artwork") { render Registry::FilmPoster.new(film: @film) }
        div(class: "rating-film-details") do
          h2 do
            plain @film.title
            if @film.release_date.present?
              plain " "
              span(class: "rating-film-year") { t("ratings.browser.film_year", year: @film.release_date.year) }
            end
          end
          render Registry::FilmLinks.new(film: @film)
          div(class: "rating-description", tabindex: "0", role: "region", aria: { label: t("ratings.browser.film_details") }) do
            overview = @film.tmdb_details.overview
            p(class: "rating-synopsis") { overview } if overview.present?
          end
        end
      end
      rating_fields
      expression_fields
    end

    def errors_section
      return unless @errors.present?

      div(id: "rating-errors", role: "alert", tabindex: "-1", class: "ui-errors") do
        h3 { t("ratings.browser.correct_errors") }
        ul { @errors.each { |error| li { error } } }
      end
    end

    def rating_fields
      fieldset(disabled: @readonly, aria: { describedby: ("rating-errors" if @errors.present?) }, class: "rating-choices") do
        legend { t("ratings.browser.choice") }
        Ratings::Rating::Values::ALL.each do |value|
          div(class: "rating-choice") do
            id = "#{@prefix}rating-#{value}"
            input(type: "radio", class: "sr-only", name: (@readonly ? "#{@prefix}value" : "value"), value:, id:, checked: @value == value, required: !@readonly)
            label(for: id) { t("ratings.values.#{value}") }
          end
        end
      end
    end

    def expression_fields
      render ExpressionList.new(expression_texts: @expression_texts, expression_draft: @expression_draft, readonly: @readonly, prefix: @prefix, errors: @errors)
    end
  end
end

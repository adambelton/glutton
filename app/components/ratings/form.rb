module Ratings
  class Form < UI::Base
    def initialize(film:, rating_film_id: nil, method: :post, value: nil, expression_texts: [], expression_draft: nil, previous_rating_id: nil, errors: nil, readonly: false)
      @film, @rating_film_id, @method, @value = film, rating_film_id, method, value
      @expression_texts, @previous_rating_id, @errors, @readonly = expression_texts, previous_rating_id, errors, readonly
      @expression_draft = expression_draft
      @prefix = readonly ? "example-#{film.tmdb_id}-" : ""
    end

    def view_template
      div(class: "rating-interface") do
        div(class: "rating-film-artwork") { render UI::FilmPoster.new(film: @film) }
        div(class: "rating-film-info") do
          h2 { @film.title }
          p(class: "muted") { t("ratings.browser.release_year", year: @film.release_date.year) } if @film.release_date.present?
          overview = @film.tmdb_details.overview
          p(class: "rating-synopsis") { overview.truncate(350, separator: " ") } if overview.present?
          span(class: "rating-trailer-icon", role: "img", aria: { label: t("ratings.browser.trailer") }) { "▷" }
        end
        div(class: "rating-interface-body") do
          errors_section
          if @readonly
            rating_fields
            expression_fields
          else
            form_with(url: rating_path, method: @method) do
              input(type: "hidden", name: "rating_film_id", value: @rating_film_id)
              input(type: "hidden", name: "previous_rating_id", value: @previous_rating_id) if @method == :patch
              rating_fields
              expression_fields
              submit(t("ratings.browser.save"))
            end
          end
        end
      end
    end

    private

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

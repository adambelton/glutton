module Ratings
  class Form < UI::Base
    def initialize(rating_film:, method:, value: nil, expression_texts: [], previous_rating_id: nil, errors: nil)
      @rating_film, @method, @value = rating_film, method, value
      @expression_texts, @previous_rating_id, @errors = expression_texts, previous_rating_id, errors
    end

    def view_template
      h2 { @rating_film.film.title }
      p { t("ratings.browser.release_year", year: @rating_film.film.release_date.year) } if @rating_film.film.release_date
      if @errors.present?
        div(id: "rating-errors", role: "alert", tabindex: "-1", class: "ui-errors") do
          h3 { t("ratings.browser.correct_errors") }
          ul { @errors.each { |error| li { error } } }
        end
      end
      form_with(url: rating_path, method: @method) do
        input(type: "hidden", name: "rating_film_id", value: @rating_film.id)
        input(type: "hidden", name: "previous_rating_id", value: @previous_rating_id) if @method == :patch
        fieldset(aria: { describedby: ("rating-errors" if @errors.present?) }, class: "rating-choices") do
          legend { t("ratings.browser.choice") }
          Ratings::Rating::Values::ALL.each do |value|
            div(class: "rating-choice") do
              input(type: "radio", name: "value", value:, id: "rating-#{value}", checked: @value == value, required: true)
              label(for: "rating-#{value}") { t("ratings.values.#{value}") }
            end
          end
        end
        details(open: @expression_texts.any?(&:present?), class: "rating-expressions") do
          summary { t("ratings.browser.expressions") }
          fieldset(aria: { describedby: @errors.present? ? "expression-help rating-errors" : "expression-help" }) do
            legend { t("ratings.browser.expressions") }
            p(id: "expression-help") { t("ratings.browser.expression_help", count: Ratings::Rating::MAX_EXPRESSIONS, length: Ratings::RatingExpression::MAX_TEXT_LENGTH) }
            Ratings::Rating::MAX_EXPRESSIONS.times do |index|
              div(class: "ui-field") do
                label(for: "expression-#{index}") { t("ratings.browser.expression", number: index + 1) }
                render RubyUI::Textarea.new(name: "expression_texts[]", id: "expression-#{index}", maxlength: Ratings::RatingExpression::MAX_TEXT_LENGTH, rows: 2, class: "ui-input") { @expression_texts[index] }
              end
            end
          end
        end
        submit(t("ratings.browser.save"))
      end
    end
  end
end

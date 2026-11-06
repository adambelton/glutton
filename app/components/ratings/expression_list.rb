module Ratings
  class ExpressionList < UI::Base
    def initialize(expression_texts:, expression_draft: nil, readonly:, prefix:, errors: nil)
      @expression_draft = expression_draft
      @expression_texts, @readonly, @prefix, @errors = expression_texts, readonly, prefix, errors
    end

    def view_template
      help_id = "#{@prefix}expression-help"
      data = unless @readonly
        { controller: "rating-expressions", "rating-expressions-limit-value": Rating::MAX_EXPRESSIONS,
          "rating-expressions-unadded-message-value": t("ratings.browser.unadded_expression"),
          "rating-expressions-limit-message-value": t("ratings.errors.invalid_expressions", count: Rating::MAX_EXPRESSIONS),
          "rating-expressions-remove-label-value": t("ratings.browser.expression_remove", number: "%{number}") }
      end
      fieldset(disabled: @readonly, class: "expression-list", data:,
        aria: { describedby: (@readonly ? nil : (@errors.present? ? "#{help_id} rating-errors" : help_id)) }) do
        legend { t("ratings.browser.expressions") }
        p(id: help_id, class: "muted") { t("ratings.browser.expression_help", count: Rating::MAX_EXPRESSIONS, length: RatingExpression::MAX_TEXT_LENGTH) } unless @readonly
        div(class: "expression-composer") do
          label(for: "#{@prefix}expression-draft", class: "sr-only") { t("ratings.browser.expression_draft") }
          render RubyUI::Textarea.new(id: "#{@prefix}expression-draft", name: "expression_draft", maxlength: RatingExpression::MAX_TEXT_LENGTH,
            rows: 2, class: "ui-input", placeholder: t("ratings.browser.expression_placeholder"), disabled: @readonly,
            data: { "rating-expressions-target": "draft", action: "keydown->rating-expressions#keydown input->rating-expressions#clearValidity" }) { @expression_draft }
          button(type: "button", hidden: !@readonly, disabled: @readonly, class: "expression-add",
            data: { "rating-expressions-target": "add", action: "rating-expressions#add" }) { t("ratings.browser.expression_add") }
        end
        ol(class: "expression-items", data: { "rating-expressions-target": "list" }) do
          @expression_texts.each_with_index { |text, index| expression_item(text:, index:) }
        end
        unless @readonly
          template(data: { "rating-expressions-target": "template" }) { expression_item(text: "", index: 0) }
        end
      end
    end

    private

    def expression_item(text:, index:)
      li(class: "expression-item") do
        p(class: "expression-copy", data: { "expression-copy": true }) { text }
        input(type: "hidden", name: "expression_texts[]", value: text) unless @readonly
        button(type: "button", disabled: @readonly, class: "expression-remove", aria: { label: t("ratings.browser.expression_remove", number: index + 1) },
          data: (@readonly ? nil : { action: "rating-expressions#remove" })) { "×" }
      end
    end
  end
end

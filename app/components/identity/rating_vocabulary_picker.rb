module Identity
  class RatingVocabularyPicker < Shared::Base
    def initialize(inline: false)
      @inline = inline
    end

    def view_template
      @options = RatingVocabularies::ALL.map { |key| Shared::RatingVocabulary.new(key) }
      controllers = @inline ? "rating-vocabulary-picker" : "confirmation-dialog rating-vocabulary-picker"
      div(class: ("rating-vocabulary-inline" if @inline),
        data: { controller: controllers,
          action: ("turbo:before-cache@document->rating-vocabulary-picker#close" if @inline),
          rating_vocabulary_picker_labels_value: @options.to_h { |option| [ option.key, option.labels ] }.to_json,
          rating_vocabulary_picker_saved_value: rating_vocabulary.key }) do
        if @inline
          yield self
        else
          account_trigger
          tag(:dialog, class: "ui-card ui-confirmation-dialog rating-vocabulary-dialog", aria: { labelledby: "rating-vocabulary-title" },
            data: { confirmation_dialog_target: "dialog", rating_vocabulary_picker_target: "dialog",
              action: "keydown.esc->rating-vocabulary-picker#close close->rating-vocabulary-picker#reset turbo:before-cache@document->confirmation-dialog#close" }) do
            h2(id: "rating-vocabulary-title") { t("rating_vocabulary.title") }
            picker_form
          end
        end
        div(id: "rating-vocabulary-status", role: "status", class: "sr-only")
      end
    end

    def inline_trigger
      label = t("rating_vocabulary.change")
      button(type: "button", hidden: true, class: "rating-vocabulary-inline-trigger ui-action-button",
        aria: { label:, controls: "rating-vocabulary-editor", expanded: "false" },
        data: { rating_vocabulary_picker_target: "trigger", action: "rating-vocabulary-picker#open", tooltip: label }) do
        trigger_symbol
      end
    end

    def inline_editor
      div(id: "rating-vocabulary-editor", class: "rating-vocabulary-editor", hidden: true,
        data: { rating_vocabulary_picker_target: "editor", action: "keydown.esc->rating-vocabulary-picker#close" }) do
        picker_form
      end
    end

    def inline_actions
      div(class: "rating-actions film-actions rating-vocabulary-actions",
        data: { action: "keydown.esc->rating-vocabulary-picker#close" }) do
        render Shared::PrimaryButton.new(type: :submit, form: "rating-vocabulary-form", class: "ui-submit",
          disabled: true, data: { rating_vocabulary_picker_target: "save" }) { t("rating_vocabulary.save") }
        cancel_button
      end
    end

    private

    def account_trigger
      render Shared::GhostButton.new(class: "ui-action-button gap-2", aria: { haspopup: "dialog" },
        data: { action: "confirmation-dialog#open" }) do
        trigger_symbol
        plain t("rating_vocabulary.change")
      end
    end

    def trigger_symbol
      render RatingVocabularySymbol.new(vocabulary: rating_vocabulary, id: "rating-vocabulary-symbol",
        data: { rating_vocabulary_picker_target: "symbol" })
    end

    def picker_form
      events = "turbo:submit-start->rating-vocabulary-picker#submitStart turbo:submit-end->rating-vocabulary-picker#submitEnd"
      data = @inline ? { action: events } : track_form_changes(baseline: { vocabulary: rating_vocabulary.key }, action: events)
      form_with(url: account_rating_vocabulary_path, method: :patch, id: "rating-vocabulary-form", class: "rating-vocabulary-form", data:) do
        div(id: "rating-vocabulary-error", role: "alert", data: { rating_vocabulary_picker_target: "error" })
        div(class: ("ui-field" unless @inline)) do
          span(id: "rating-vocabulary-choice-label", class: ("sr-only" if @inline)) { t("rating_vocabulary.title") }
          input(type: "hidden", name: "vocabulary", value: rating_vocabulary.key, data: { rating_vocabulary_picker_target: "value" })
          details(class: "rating-vocabulary-options", data: { rating_vocabulary_picker_target: "options" }) do
            summary(class: "ui-input", aria: { labelledby: "rating-vocabulary-choice-label rating-vocabulary-current-option" },
              data: { rating_vocabulary_picker_target: "summary" }) do
              span(id: "rating-vocabulary-current-option", data: { rating_vocabulary_picker_target: "currentOption" }) do
                option_caption(rating_vocabulary)
              end
            end
            ul(class: "rating-vocabulary-option-list", role: "list") do
              @options.each do |option|
                li do
                  button(type: "button", data: { rating_vocabulary_picker_target: "option",
                    rating_vocabulary_picker_key_param: option.key, action: "rating-vocabulary-picker#choose" }) do
                    option_caption(option)
                  end
                end
              end
            end
          end
        end
        unless @inline
          fieldset(class: "rating-choices", aria: { live: "polite", atomic: true }) do
            legend { t("rating_vocabulary.preview") }
            rating_vocabulary.labels.each do |value, label|
              render ::Ratings::Choice.new(value:, label:)
            end
          end
          render Shared::ActionRow.new(full_width: true) do
            cancel_button
            validated_submit(t("rating_vocabulary.save"), class_name: "ui-action-button")
          end
        end
      end
    end

    def cancel_button
      render Shared::GhostButton.new(class: "ui-action-button",
        data: { action: "rating-vocabulary-picker#close" }) { t("identity.settings.cancel") }
    end

    def option_caption(vocabulary)
      render RatingVocabularySymbol.new(vocabulary:)
      plain vocabulary.name
    end
  end
end

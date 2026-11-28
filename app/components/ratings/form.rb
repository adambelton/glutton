module Ratings
  class Form < Shared::Base
    def initialize(film:, rating_film_id: nil, method: :post, value: nil, notes: nil, previous_rating_id: nil, errors: nil, readonly: false, dismissible: false, requested_film_id: nil, saved_rating: nil)
      @film, @rating_film_id, @method, @value = film, rating_film_id, method, value
      @notes, @previous_rating_id, @errors, @readonly = notes, previous_rating_id, errors, readonly
      @dismissible, @requested_film_id = dismissible, requested_film_id
      @saved_rating = saved_rating
      @prefix = readonly ? "example-#{film.tmdb_id}-" : ""
    end

    def view_template
      data = { controller: "rating-panels" }
      unless @readonly
        data[:controller] += " rating-selection"
        data[:rating_selection_baseline_value] = saved_baseline&.to_json
        data[:rating_selection_notes_description_value] = t("ratings.browser.panels.has_notes")
      end
      render Shared::FilmCard.new(layout: "rating-interface", data:) do
        errors_section
        unless @readonly
          form_with(url: rating_path, method: @method, id: "rating-form", html: { hidden: true }) do
            input(type: "hidden", name: "rating_film_id", value: @rating_film_id)
            input(type: "hidden", name: "film_id", value: @requested_film_id) if @requested_film_id.present?
            input(type: "hidden", name: "previous_rating_id", value: @previous_rating_id) if @method == :patch
          end
        end
        if !@readonly && current_user.can_view_account?
          render ::Identity::RatingVocabularyPicker.new(inline: true) do |picker|
            workspace(picker:)
            actions
            picker.inline_actions
          end
        else
          workspace
          actions
        end
      end
    end

    private

    def workspace(picker: nil)
      overview = @film.tmdb_details.overview
      div(class: "rating-film-artwork") { render Registry::FilmPoster.new(film: @film) }
      div(class: "rating-film-details") do
        header(class: "rating-film-header") do
          div(class: "rating-film-heading") do
            h2 { render Registry::FilmTitle.new(film: @film) }
            render Registry::FilmLinks.new(film: @film, readonly: @readonly)
          end
          if overview.present?
            div(class: "rating-mobile-synopsis") do
              render Shared::FilmSynopsis.new(text: overview, id: "#{@prefix}rating-mobile-synopsis")
            end
          end
          panel_tabs
        end
        div(class: "rating-panels") do
          panel("rating") do
            render Shared::FilmSynopsis.new(text: overview, id: "#{@prefix}rating-synopsis")
            if picker.present?
              div(class: "rating-vocabulary-fields") do
                div(class: "rating-vocabulary-heading") do
                  div(class: "rating-vocabulary-prompt", data: { rating_vocabulary_picker_target: "prompt" }) do
                    span(id: "rating-choice-prompt") { t("ratings.browser.choice") }
                    picker.inline_trigger
                  end
                  picker.inline_editor
                end
                rating_fields(picker:)
              end
            else
              rating_fields
            end
          end
          panel("journal") { notes_field }
        end
      end
    end

    def panel_tabs
      div(class: "rating-tabs", role: "tablist", hidden: true, aria: { label: t("ratings.browser.panels.label") },
        data: { rating_panels_target: "tabs", action: "keydown->rating-panels#navigate" }) do
        %w[rating journal].each do |name|
          journal = name == "journal"
          button(type: "button", id: "#{@prefix}#{name}-tab", role: "tab",
            aria: { controls: "#{@prefix}#{name}-panel", description: (t("ratings.browser.panels.has_notes") if journal && @notes.present?) },
            data: { rating_panels_target: "tab", rating_selection_target: ("journalTab" if journal && !@readonly), action: "rating-panels#select" }) do
            plain t("ratings.browser.panels.#{name}")
            if journal
              span(class: "rating-tab-notes", hidden: @notes.blank?, data: ({ rating_selection_target: "notesIndicator" } unless @readonly)) do
                render ::Library::NotesIcon.new
              end
            end
          end
        end
      end
    end

    def panel(name, &block)
      div(id: "#{@prefix}#{name}-panel", class: "rating-panel", role: "tabpanel",
        tabindex: ("0" if name == "rating"),
        aria: { labelledby: "#{@prefix}#{name}-tab" }, data: { rating_panels_target: "panel" }, &block)
    end

    def errors_section
      return unless @errors.present?

      div(id: "rating-errors", role: "alert", tabindex: "-1", class: "ui-errors") do
        h3 { t("ratings.browser.correct_errors") }
        ul { @errors.each { |error| li { error } } }
      end
    end

    def rating_fields(picker: nil)
      fieldset(disabled: @readonly, aria: { describedby: ("rating-errors" if @errors.present?),
        labelledby: ("rating-choice-prompt" if picker.present?), live: ("polite" if picker.present?) }, class: "rating-choices",
        data: ({ action: "change->rating-selection#update", rating_vocabulary_picker_target: ("choices" if picker.present?) } unless @readonly)) do
        legend { t("ratings.browser.choice") } unless picker.present?
        Ratings::Rating::Values::ALL.each do |value|
          id = "#{@prefix}rating-#{value}"
          render Choice.new(value:, label: rating_vocabulary.label(value), input_id: id) do
            input(type: "radio", form: ("rating-form" unless @readonly), class: "sr-only",
              name: (@readonly ? "#{@prefix}value" : "value"), value:, id:, checked: @value == value, required: !@readonly,
              data: ({ rating_selection_target: "choice", rating_vocabulary_picker_target: ("rating" if picker.present?) } unless @readonly))
          end
        end
      end
    end

    def saved_baseline
      return unless @saved_rating.present?

      { value: @saved_rating.value, notes: browser_notes(@saved_rating.notes) }
    end

    def is_dirty?
      return true unless @saved_rating.present?

      saved_baseline != { value: @value, notes: browser_notes(@notes) }
    end

    def browser_notes(notes)
      notes.to_s.gsub(/\r\n?/, "\n")
    end

    def actions
      div(class: "rating-actions film-actions", data: { readonly: ("true" if @readonly) }) do
        valid_rating = Ratings::Rating::Values::ALL.include?(@value)
        tooltip = t(@saved_rating.present? && valid_rating ? "ratings.browser.save_unchanged" : "ratings.browser.save_disabled") unless @readonly
        render Shared::PrimaryButton.new(type: :submit, form: ("rating-form" unless @readonly), class: "ui-submit",
          disabled: @readonly || !is_dirty? || !valid_rating,
          data: ({ rating_selection_target: "save", tooltip: } unless @readonly)) { t("ratings.browser.save") }
        if @dismissible
          render Shared::ActionForm.new(url: dismiss_rating_path, params: { rating_film_id: @rating_film_id }, readonly: @readonly) do
            render Shared::GhostButton.new(type: :submit, disabled: @readonly, class: "ui-action-button") { t("ratings.browser.dismiss") }
          end
          tooltip_text = t("library.detail.add_to_watchlist")
          render ::Library::FilmActionForm.new(url: add_to_watchlist_from_ratings_path, params: { film_id: @film.id },
            action_label: tooltip_text, film_title: @film.title, readonly: @readonly) do
            render Shared::IconButton.new(type: :submit, disabled: @readonly, variant: :secondary, size: :xl, class: "ui-action-button",
              aria: { label: tooltip_text }, data: { tooltip: tooltip_text }) { render ::Library::BookmarkPlusIcon.new }
          end
        end
      end
    end

    def notes_field
      id = "#{@prefix}notes"
      div(class: "rating-notes") do
        label(for: id) { t("ratings.browser.notes") }
        textarea(id:, name: "notes", form: ("rating-form" unless @readonly), rows: 8, maxlength: Rating::MAX_NOTES_LENGTH, class: "ui-input",
          data: ({ rating_selection_target: "notes", action: "input->rating-selection#update" } unless @readonly),
          readonly: @readonly, placeholder: t("ratings.browser.notes_placeholder"),
          aria: { describedby: ("rating-errors" if @errors.present?) }) { plain "\n#{@notes}" }
      end
    end
  end
end

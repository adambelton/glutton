module Identity
  class LibraryPreview < Shared::Base
    def initialize(films:)
      @films = films
    end

    def view_template
      div(class: "demo-browser library-page library-preview", data: { controller: "library-preview",
        library_preview_count_one_value: t("identity.entry.library_count", count: 1),
        library_preview_count_other_value: t("identity.entry.library_count", count: "%{count}") }) do
        div(class: "ui-page-heading") do
          h3 { t("library.browser.title") }
          fieldset(disabled: true, class: "library-preview-search") do
            render ::Library::FilmSearchForm.new(dropdown: true)
          end
        end
        ::Library::CollectionManagement::Browse::Views::ALL.each { |view| library_sample(view) }
        p(class: "library-preview-status", aria: { live: "polite", atomic: "true" }, data: { library_preview_target: "status" })
      end
    end

    private

    def library_sample(view)
      watched = view == ::Library::CollectionManagement::Browse::Views::WATCHED
      samples = watched ? MarketingSamples::WATCHED : MarketingSamples::RECOMMENDATION_FILM_IDS.map { |id| { tmdb_id: id, rating: nil, notes: false } }
      samples = samples.select { |sample| @films[sample.fetch(:tmdb_id)].present? }
      entries = samples.map { |sample| ::Library::LibraryFilm.new(film: @films.fetch(sample.fetch(:tmdb_id)), watched:) }
      ratings = []
      div(class: "library-preview-panel", hidden: view != "watchlist", data: { library_preview_target: "panel", view: }) do
        render ::Library::Collection.new(view:, page: ::Library::CollectionManagement::Browse::Page.new(entries:, next_page: false),
          page_number: 1, ratings:, local_browsing: true) do |library_film, index|
          sample_library_actions(library_film.film, watched:, sample: samples.fetch(index))
        end
        p(class: "library-preview-empty", hidden: true) { t("identity.entry.library_empty") }
      end
    end

    def sample_library_actions(film, watched:, sample:)
      value = sample.fetch(:rating)
      notes = sample.fetch(:notes)
      div(class: "library-card-actions", data: { sample_rating: (value || ::Library::CollectionManagement::Browse::UNRATED if watched) }) do
        if watched
          label = value.present? ? t("library.browser.edit_film_rating", title: film.title) : t("library.browser.rate_film", title: film.title)
          render ::Library::CardAction.new(label:, tooltip: nil, readonly: true, class: "ui-action-button library-rating-icon",
            aria: { label:, description: t(notes ? "library.browser.notes_present" : "library.browser.notes_absent") }) do
            render ::Library::RatingIndicator.new(value:, notes:)
          end
          sample_library_action(film, :move_to_watchlist, :move_film_to_watchlist, ::Library::BookmarkPlusIcon.new)
          sample_library_action(film, :remove_from_library, :remove_film_from_library, ::Library::BookmarkMinusIcon.new)
        else
          sample_library_action(film, :move_to_watched, :move_film_to_watched, ::Library::EyeCheckIcon.new)
          sample_library_action(film, :remove_from_watchlist, :remove_film, ::Library::BookmarkMinusIcon.new)
        end
      end
    end

    def sample_library_action(film, tooltip, label, icon)
      render ::Library::CardAction.new(label: t("library.detail.#{label}", title: film.title),
        tooltip: t("library.detail.#{tooltip}"), readonly: true) { render icon }
    end
  end
end

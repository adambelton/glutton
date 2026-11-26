module Identity
  class LibraryPreview < Shared::Base
    def initialize(films:)
      @films = films
    end

    def view_template
      div(class: "demo-browser library-page library-preview", data: { controller: "library-preview" }) do
        ::Library::CollectionManagement::BrowseFilmCollection::Views::ALL.each { |view| library_sample(view) }
      end
    end

    private

    def library_sample(view)
      watched = view == ::Library::CollectionManagement::BrowseFilmCollection::Views::WATCHED
      samples = watched ? MarketingSamples::WATCHED : MarketingSamples::WATCHLIST_FILM_IDS.map { |id| { tmdb_id: id, rating: nil, notes: false } }
      samples = samples.select { |sample| @films[sample.fetch(:tmdb_id)].present? }
      entries = samples.map { |sample| ::Library::LibraryFilm.new(film: @films.fetch(sample.fetch(:tmdb_id)), watched_at: (Time.current if watched)) }
      ratings = []
      div(class: "library-preview-panel", hidden: view != "watchlist", data: { library_preview_target: "panel", view: }) do
        div(class: "ui-page-heading") do
          h3 { t("library.browser.title") }
          fieldset(disabled: true, class: "library-preview-search") do
            render Shared::CollectionSearchField.new(label: t("library.browser.search.#{view}"), controls: nil, input_data: {}, clear_data: {})
          end
        end
        render ::Library::FilmCollection.new(view:, page: ::Library::CollectionManagement::BrowseFilmCollection::Page.new(entries:, next_page: false),
          page_number: 1, ratings:, preview: true) do |library_film, index|
          sample = samples.fetch(index)
          value = sample.fetch(:rating)
          sample_rating = value || ::Library::CollectionManagement::BrowseFilmCollection::UNRATED if watched
          render ::Library::LibraryFilmCardControls.new(library_film:, readonly: true, rating_value: value, has_notes: sample.fetch(:notes),
            data: { sample_rating: })
        end
        p(class: "library-preview-empty", hidden: true) { t("identity.entry.library_empty") }
      end
    end
  end
end

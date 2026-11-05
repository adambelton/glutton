module Views
  module Library
    class FilmDetail < ::Views::Base
      def initialize(library_film:)
        @library_film = library_film
      end

      def view_template
        page(title: @library_film.film.title, class: "library-page") do
          p { t("library.browser.released", year: @library_film.film.release_date.year) } if @library_film.film.release_date
          render ::Library::RatingStatus.new(library_film: @library_film)
          div(class: "library-actions") do
            action(:mark_watched, :mark_film_watched, mark_watched_library_film_path(@library_film)) if @library_film.can_watch?
            action(:remove, :remove_film, remove_from_watchlist_library_film_path(@library_film), method: :delete) if @library_film.can_remove_from_watchlist?
            action(:mark_not_interested, :dismiss_film, mark_not_interested_library_film_path(@library_film)) if @library_film.can_mark_not_interested?
            action(:add_to_watchlist, :watchlist_film, add_to_watchlist_library_film_path(@library_film)) if @library_film.can_add_to_watchlist?
            action(:remove_from_not_interested, :remove_film_from_not_interested, remove_from_not_interested_library_film_path(@library_film), method: :delete) if @library_film.can_remove_from_not_interested?
          end
          p { text_link(t("library.browser.return"), library_path) }
        end
      end

      private

      def action(text_key, label_key, url, method: :post)
        render UI::ActionButton.new(text: t("library.detail.#{text_key}"), url:, method:,
          aria: { label: t("library.detail.#{label_key}", title: @library_film.film.title) })
      end
    end
  end
end

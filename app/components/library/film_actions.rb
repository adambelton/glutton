module Library
  class FilmActions < Shared::Base
    def initialize(library_film:)
      @library_film = library_film
    end

    def view_template
      div(class: "library-card-actions") do
        if @library_film.watched?
          render RatingPrompt.new(library_film: @library_film)
          action(:move_to_watchlist, :move_film_to_watchlist, BookmarkPlus.new, move_to_watchlist_library_film_path(@library_film))
          action(:remove_from_library, :remove_film_from_library, BookmarkMinus.new, remove_from_watched_library_film_path(@library_film), method: :delete)
        else
          action(:mark_watched, :mark_film_watched, EyeCheck.new, mark_watched_library_film_path(@library_film))
          action(:remove_from_watchlist, :remove_film, BookmarkMinus.new, remove_from_watchlist_library_film_path(@library_film), method: :delete)
        end
      end
    end

    private

    def action(tooltip, label, icon, url, method: :post)
      render Shared::ActionButton.new(text: t("library.detail.#{tooltip}"), url:, method:, icon:,
        aria: { label: t("library.detail.#{label}", title: @library_film.film.title) })
    end
  end
end

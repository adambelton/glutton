module Library
  class LibraryFilmCardControls < Shared::Base
    def initialize(library_film:)
      @library_film = library_film
    end

    def view_template
      div(class: "library-card-actions") do
        render RatingIconButton.new(library_film: @library_film) if @library_film.watched?
        if @library_film.can_move_to_watchlist?
          action(:move_to_watchlist, :move_film_to_watchlist, BookmarkPlusIcon.new, move_to_watchlist_library_film_path(@library_film))
        end
        if @library_film.can_remove_from_watched?
          action(:remove_from_library, :remove_film_from_library, BookmarkMinusIcon.new, remove_from_watched_library_film_path(@library_film), method: :delete)
        end
        if @library_film.can_move_to_watched?
          action(:move_to_watched, :move_film_to_watched, EyeCheckIcon.new, move_to_watched_library_film_path(@library_film))
        end
        if @library_film.can_remove_from_watchlist?
          action(:remove_from_watchlist, :remove_film, BookmarkMinusIcon.new, remove_from_watchlist_library_film_path(@library_film), method: :delete)
        end
      end
    end

    private

    def action(tooltip, label, icon, url, method: :post)
      tooltip_text = t("library.detail.#{tooltip}")
      render Shared::ActionForm.new(url:, method:) do
        render Shared::IconButton.new(type: :submit, variant: :ghost, size: :xl, class: "ui-action-button",
          aria: { label: t("library.detail.#{label}", title: @library_film.film.title) }, data: { tooltip: tooltip_text }) { render icon }
      end
    end
  end
end

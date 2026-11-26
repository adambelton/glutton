module Library
  class LibraryFilmCardControls < Shared::Base
    def initialize(library_film:, readonly: false, rating_value: nil, has_notes: false, data: {})
      @library_film = library_film
      @readonly, @rating_value, @has_notes, @data = readonly, rating_value, has_notes, data
    end

    def view_template
      div(class: "library-card-actions", data: @data) do
        @library_film.watched? ? watched_actions : watchlist_actions
      end
    end

    private

    def watched_actions
      render RatingIconButton.new(library_film: @library_film, readonly: @readonly, value: @rating_value, notes: @has_notes)
      if @readonly || @library_film.can_remove_from_watched?
        action(:remove_from_library, :remove_film_from_library, BookmarkMinusIcon.new, method: :delete) do
          remove_from_watched_library_film_path(@library_film)
        end
      end
    end

    def watchlist_actions
      if @readonly || @library_film.can_move_to_watched?
        action(:move_to_watched, :move_film_to_watched, EyeCheckIcon.new) { move_to_watched_library_film_path(@library_film) }
      end
      if @readonly || @library_film.can_remove_from_watchlist?
        action(:remove_from_watchlist, :remove_film, BookmarkMinusIcon.new, method: :delete) do
          remove_from_watchlist_library_film_path(@library_film)
        end
      end
    end

    def action(tooltip, label, icon, method: :post)
      title = @library_film.film.title
      url = yield unless @readonly
      render CardAction.new(url:, method:, film_title: title, label: t("library.detail.#{label}", title:),
        tooltip: t("library.detail.#{tooltip}"), readonly: @readonly) { render icon }
    end
  end
end

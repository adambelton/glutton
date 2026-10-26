class LibraryFilmToWatch < LibraryFilm
  def can_remove_from_watchlist?
    true
  end

  def can_confirm_watched?
    true
  end

  def can_mark_not_interested?
    true
  end

  def can_watch?
    true
  end
end

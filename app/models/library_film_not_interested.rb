class LibraryFilmNotInterested < LibraryFilm
  def can_remove_from_not_interested?
    true
  end

  def can_confirm_watched?
    true
  end

  def can_add_to_watchlist?
    true
  end
end

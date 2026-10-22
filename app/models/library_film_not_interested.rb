class LibraryFilmNotInterested < LibraryFilm
  def can_confirm_watched?
    true
  end

  def can_add_to_watchlist?
    true
  end
end

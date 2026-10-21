class LibraryFilmToWatch < LibraryFilm
  def can_mark_not_interested?
    true
  end

  def can_watch?
    true
  end
end

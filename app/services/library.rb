module Library
  EVENTS_PUBLISHING_DOMAIN = "library".freeze

  module Events
    FILM_MARKED_WATCHED = "FilmMarkedWatched".freeze
    FILM_ADDED_TO_WATCHLIST = "FilmAddedToWatchlist".freeze
    FILM_MARKED_NOT_INTERESTED = "FilmMarkedNotInterested".freeze
    FILM_REMOVED_FROM_WATCHLIST = "FilmRemovedFromWatchlist".freeze
    FILM_DISMISSAL_REMOVED = "FilmDismissalRemoved".freeze
  end
end

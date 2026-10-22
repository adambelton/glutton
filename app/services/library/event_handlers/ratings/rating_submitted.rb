module Library
  module EventHandlers
    module Ratings
      class RatingSubmitted
        def self.call(event:, user:, film:, library_film:)
          if library_film.nil?
            library_film = LibraryFilmWatched.create!(user:, film:)
          elsif library_film.can_confirm_watched?
            library_film = library_film.becomes!(LibraryFilmWatched)
            library_film.save!
          else
            return :ignored
          end

          library_film.publish_event!(name: Events::FILM_MARKED_WATCHED,
            correlation_id: event.correlation_id, causation_id: event.id)
          :processed
        end
      end
    end
  end
end

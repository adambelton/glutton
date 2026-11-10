module Ratings
  class TasteProfileEvidenceChanges
    attr_reader :changes, :retained, :current_by_film

    def initialize(previous:, current:)
      previous_by_film = previous.index_by { |note| note.fetch("film_id") }
      @current_by_film = current.index_by { |note| note.fetch("film_id") }
      @retained = {}
      @changes = (previous_by_film.keys | @current_by_film.keys).filter_map do |film_id|
        before, after = previous_by_film[film_id], @current_by_film[film_id]
        if before&.fetch("text") == after&.fetch("text")
          @retained[before.fetch("rating_id")] = after
          next
        end

        [ before, after ]
      end
    end
  end
end

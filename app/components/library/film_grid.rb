module Library
  class FilmGrid < Shared::Base
    def initialize(entries:)
      @entries = entries
    end

    def view_template(&block)
      ul(class: "library-films") do
        @entries.each_with_index do |library_film, index|
          li(class: "library-film") do
            film = library_film.film
            render ::Registry::FilmPoster.new(film:)
            if block.present?
              yield library_film, index
            else
              render ::Library::LibraryFilmCardControls.new(library_film:)
            end
            h3 { render ::Registry::FilmTitle.new(film:) }
          end
        end
      end
    end
  end
end

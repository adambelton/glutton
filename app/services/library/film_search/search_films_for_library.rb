module Library
  module FilmSearch
    class SearchFilmsForLibrary
      def self.call(user_id:, query:, page:, batch:)
        BuildFilmSearchResults.call(user_id:, batch:) do
          Registry::Sources::SearchTmdbFilms.call(query:, page:,
            genre_id: Registry::Sources::SearchTmdbFilms::HORROR_GENRE_ID)
        end
      end
    end
  end
end

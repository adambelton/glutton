module Library
  module TmdbFilmSearch
    class SearchTmdbFilmsForLibrary
      def self.call(user_id:, query:, page:, offset:, backwards:, legacy_batch:)
        ActivityMonitoring.current_operation_span&.set_operation(ActivityMonitoring::Operations::SEARCH_FILMS)
        cursor = PaginateTmdbMatches::Cursor.new(page, offset)
        paginator = PaginateTmdbMatches.new do |provider_page|
          Registry::Sources::SearchTmdbFilms.call(query:, page: provider_page, genre_id: Registry::Sources::SearchTmdbFilms::HORROR_GENRE_ID)
        end
        BuildTmdbFilmSearchResults.call(user_id:) { paginator.call(cursor:, backwards:, legacy_batch:) }
      end
    end
  end
end

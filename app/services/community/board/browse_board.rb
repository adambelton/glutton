module Community
  module Board
    class BrowseBoard
      def self.call(viewer:, number:, query:)
        catalogue = Registry::CatalogueQueries::BrowseCatalogue
        watched_film_ids = Library::CollectionManagement::BrowseWatchedFilms.film_ids(user_id: viewer.id)
        watched_films = catalogue.film_titles(film_ids: watched_film_ids, title_query: query)

        BrowseCommunityBoard.new(watched_films:, matching_film_ids: catalogue.film_ids(title_query: query), query:)
          .page(number:) do |placeholder_film_ids|
          catalogue.films_for_ids(film_ids: placeholder_film_ids).index_by(&:id)
        end
      end
    end
  end
end

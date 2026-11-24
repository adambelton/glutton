module Ratings
  module CandidateSelection
    class BrowseInitialRatingFilms
      BATCH_SIZE = 24
      CataloguePage = Data.define(:films, :number, :next_number)

      def self.call(page:)
        ids = Registry::CatalogueQueries::FilmIdsByTmdbVoteCount.call(
          excluding_ids: [], limit: BATCH_SIZE + 1, offset: (page - 1) * BATCH_SIZE)
        page_ids = ids.first(BATCH_SIZE)
        films_by_id = Registry::Film.where(id: page_ids).index_by(&:id)
        films = page_ids.filter_map { |id| films_by_id[id] }
        CataloguePage.new(films:, number: page, next_number: (page + 1 if ids.size > BATCH_SIZE))
      end
    end
  end
end

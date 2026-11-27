module Registry
  module CatalogueQueries
    class BrowseCatalogue
      COLLECTION_PAGE_SIZE = 10
      DETAIL_PAGE_SIZE = 25
      FilmDetail = Data.define(:film, :associations)
      CategoryDetail = Data.define(:category, :qualities)
      QualityDetail = Data.define(:quality, :films)

      def self.films(page:, title_query:)
        CountedPage.load(matching_films(title_query:).order(:title, :id), number: page, page_size: COLLECTION_PAGE_SIZE)
      end

      def self.film_ids(title_query:)
        matching_films(title_query:).select(:id)
      end

      def self.film_titles(film_ids:, title_query:)
        matching_films(title_query:).where(id: film_ids).select("films.id AS film_id, LOWER(films.title) AS film_title")
      end

      def self.films_for_ids(film_ids:)
        Film.where(id: film_ids)
      end

      def self.matching_films(title_query:)
        title_query.present? ? Film.matching_title(title_query) : Film.all
      end
      private_class_method :matching_films

      def self.categories(page:, query: "")
        records = QualityCategory.order(:name, :id)
        records = records.where("name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%") if query.present?
        CountedPage.load(records, number: page, page_size: COLLECTION_PAGE_SIZE)
      end

      def self.qualities(page:, query: "")
        records = Quality.includes(:quality_category).order(:name, :id)
        records = records.where("name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%") if query.present?
        CountedPage.load(records, number: page, page_size: COLLECTION_PAGE_SIZE)
      end

      def self.film(id:, page:)
        film = Film.find(id)
        associations = film.film_qualities.joins(quality: :quality_category)
          .includes(:film_quality_eval, quality: :quality_category)
          .order("quality_categories.name", "qualities.name", "film_qualities.id")
        FilmDetail.new(film:, associations: CountedPage.load(associations, number: page, page_size: DETAIL_PAGE_SIZE))
      end

      def self.category(id:, page:)
        category = QualityCategory.find(id)
        qualities = CountedPage.load(category.qualities.order(:name, :id), number: page, page_size: DETAIL_PAGE_SIZE)
        CategoryDetail.new(category:, qualities:)
      end

      def self.quality(id:, page:)
        quality = Quality.includes(:quality_category).find(id)
        films = CountedPage.load(quality.films.order(:title, :id), number: page, page_size: DETAIL_PAGE_SIZE)
        QualityDetail.new(quality:, films:)
      end
    end
  end
end

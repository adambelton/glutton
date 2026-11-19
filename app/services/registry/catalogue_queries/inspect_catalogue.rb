module Registry
  module CatalogueQueries
    class InspectCatalogue
      COLLECTION_PAGE_SIZE = 10
      DETAIL_PAGE_SIZE = 25
      Page = Data.define(:entries, :number, :total, :total_pages)
      FilmDetail = Data.define(:film, :associations)
      CategoryDetail = Data.define(:category, :qualities)
      QualityDetail = Data.define(:quality, :films)

      def self.films(page:, query: "")
        records = Film.order(:title, :id)
        records = records.where("title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%") if query.present?
        paginate(records, page:, page_size: COLLECTION_PAGE_SIZE)
      end

      def self.categories(page:, query: "")
        records = QualityCategory.order(:name, :id)
        records = records.where("name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%") if query.present?
        paginate(records, page:, page_size: COLLECTION_PAGE_SIZE)
      end

      def self.qualities(page:, query: "")
        records = Quality.includes(:quality_category).order(:name, :id)
        records = records.where("name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%") if query.present?
        paginate(records, page:, page_size: COLLECTION_PAGE_SIZE)
      end

      def self.film(id:, page:)
        film = Film.find(id)
        associations = film.film_qualities.joins(quality: :quality_category)
          .includes(:film_quality_eval, quality: :quality_category)
          .order("quality_categories.name", "qualities.name", "film_qualities.id")
        FilmDetail.new(film:, associations: paginate(associations, page:))
      end

      def self.category(id:, page:)
        category = QualityCategory.find(id)
        CategoryDetail.new(category:, qualities: paginate(category.qualities.order(:name, :id), page:))
      end

      def self.quality(id:, page:)
        quality = Quality.includes(:quality_category).find(id)
        QualityDetail.new(quality:, films: paginate(quality.films.order(:title, :id), page:))
      end

      def self.paginate(records, page:, page_size: DETAIL_PAGE_SIZE)
        total = records.count
        entries = records.offset((page - 1) * page_size).limit(page_size).to_a
        Page.new(entries:, number: page, total:, total_pages: [ (total.to_f / page_size).ceil, 1 ].max)
      end
      private_class_method :paginate
    end
  end
end

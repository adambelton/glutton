module Registry
  module CatalogueQueries
    class InspectCatalogue
      PAGE_SIZE = 25
      Page = Data.define(:entries, :number, :total, :next_page)
      FilmDetail = Data.define(:film, :associations)
      CategoryDetail = Data.define(:category, :qualities)
      QualityDetail = Data.define(:quality, :films)

      def self.films(page:)
        paginate(Film.order(:title, :id), page:)
      end

      def self.categories(page:)
        paginate(QualityCategory.order(:name, :id), page:)
      end

      def self.qualities(page:)
        paginate(Quality.includes(:quality_category).order(:name, :id), page:)
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

      def self.paginate(records, page:)
        total = records.count
        entries = records.offset((page - 1) * PAGE_SIZE).limit(PAGE_SIZE).to_a
        Page.new(entries:, number: page, total:, next_page: page * PAGE_SIZE < total)
      end
      private_class_method :paginate
    end
  end
end

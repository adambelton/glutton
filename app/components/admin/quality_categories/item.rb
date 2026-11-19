module Admin
  module QualityCategories
    class Item < CatalogueComponent
      def initialize(detail:)
        @category, @qualities = detail.category, detail.qualities
      end

      def view_template
        p(class: "admin-detail-description") { t(:category_description) }
        section(class: "admin-detail-section", aria: { labelledby: "category-settings-heading" }) do
          h2(id: "category-settings-heading") { t(:category_settings) }
          dl(class: "admin-facts") do
            field(:maximum, @category.maximum_qualities.to_s)
            field(:weight, @category.weight.to_s("F"))
          end
        end
        section(class: "admin-detail-section") do
          section_heading(:qualities, count: @qualities.total)
          render ::Admin::Qualities::Collection.new(page: @qualities, category: false)
          pagination(@qualities, path: admin_quality_category_path(@category))
        end
      end
    end
  end
end

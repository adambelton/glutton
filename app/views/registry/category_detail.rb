module Views
  module Registry
    class CategoryDetail < Base
      def initialize(detail:)
        @category, @qualities = detail.category, detail.qualities
      end

      def view_template
        shell(title: @category.name, active: :categories, description: t(:category_description)) do
          a(href: registry_quality_categories_path, class: "back-link") { t(:all_categories) }
          dl(class: "registry-facts") do
            field(:maximum, @category.maximum_qualities.to_s)
            field(:weight, @category.weight.to_s("F"))
          end
          section(class: "registry-panel") do
            section_heading(:qualities, count: @qualities.total)
            quality_table(@qualities, category: false)
            pagination(@qualities, path: registry_quality_category_path(@category))
          end
        end
      end
    end
  end
end

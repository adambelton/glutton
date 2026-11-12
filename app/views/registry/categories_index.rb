module Views
  module Registry
    class CategoriesIndex < Base
      def initialize(page:)
        @page = page
      end

      def view_template
        shell(active: :categories, description: t(:categories_description)) do
          section(class: "registry-panel") do
            section_heading(:categories, count: @page.total)
            if @page.entries.empty?
              empty
            else
              table([ :category, :maximum, :weight ], caption: t(:categories)) do
                @page.entries.each do |category|
                  render RubyUI::TableRow.new do
                    cell { record_link(category.name, registry_quality_category_path(category)) }
                    cell { category.maximum_qualities }
                    cell { category.weight.to_s("F") }
                  end
                end
              end
            end
            pagination(@page, path: registry_quality_categories_path)
          end
        end
      end
    end
  end
end

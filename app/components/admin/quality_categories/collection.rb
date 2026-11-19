module Admin
  module QualityCategories
    class Collection < CatalogueComponent
      def initialize(page:)
        @page = page
      end

      def view_template
        if @page.entries.empty?
          empty
        else
          table([ :category, :maximum, :weight ], caption: t(:categories)) do
            @page.entries.each do |category|
              render RubyUI::TableRow.new do
                cell { record_link(category.name, admin_quality_category_path(category)) }
                cell { category.maximum_qualities }
                cell { category.weight.to_s("F") }
              end
            end
          end
        end
      end
    end
  end
end

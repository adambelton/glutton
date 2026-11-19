module Admin
  module Qualities
    class Collection < CatalogueComponent
      def initialize(page:, category: true)
        @page = page
        @category = category
      end

      def view_template
        render_table(@page)
      end

      private

      def render_table(page)
        if page.entries.empty?
          empty
        else
          headers = @category ? [ :quality, :category, :definition ] : [ :quality, :definition ]
          table(headers, caption: t(:qualities)) do
            page.entries.each do |quality|
              render RubyUI::TableRow.new do
                cell { record_link(quality.name, admin_quality_path(quality)) }
                cell { record_link(quality.quality_category.name, admin_quality_category_path(quality.quality_category)) } if @category
                cell { p(class: "definition-preview") { quality.match_rule.presence || t(:not_stored) } }
              end
            end
          end
        end
      end
    end
  end
end

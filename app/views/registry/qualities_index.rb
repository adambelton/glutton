module Views
  module Registry
    class QualitiesIndex < Base
      def initialize(page:)
        @page = page
      end

      def view_template
        shell(active: :qualities, description: t(:qualities_description)) do
          section(class: "registry-panel") do
            section_heading(:qualities, count: @page.total)
            quality_table(@page)
            pagination(@page, path: registry_qualities_path)
          end
        end
      end
    end
  end
end

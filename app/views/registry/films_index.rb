module Views
  module Registry
    class FilmsIndex < Base
      def initialize(page:)
        @page = page
      end

      def view_template
        shell(title: t(:films), active: :films, description: t(:films_description)) do
          section(class: "registry-panel") do
            section_heading(:canonical_films, count: @page.total)
            film_table(@page)
            pagination(@page, path: registry_films_path)
          end
        end
      end
    end
  end
end

module Admin
  module Films
    class Collection < CatalogueComponent
      def initialize(page:)
        @page = page
      end

      def view_template
        render_table(@page)
      end

      private

      def render_table(page)
        if page.entries.empty?
          empty
        else
          table([ :film, :release_date, :tmdb_id ], caption: t(:films)) do
            page.entries.each do |film|
              render RubyUI::TableRow.new do
                cell do
                  a(href: admin_film_path(film), class: "record-link") { render ::Registry::FilmTitle.new(film:) }
                end
                cell { film.release_date ? I18n.l(film.release_date, format: :long) : t(:not_stored) }
                cell { film.tmdb_id || t(:not_stored) }
              end
            end
          end
        end
      end
    end
  end
end

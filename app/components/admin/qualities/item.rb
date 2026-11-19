module Admin
  module Qualities
    class Item < CatalogueComponent
      def initialize(detail:)
        @quality, @films = detail.quality, detail.films
      end

      def view_template
        p(class: "admin-detail-description") { t(:quality_description) }
        dl(class: "admin-facts") do
          div do
            dt { t(:category) }
            dd { record_link(@quality.quality_category.name, admin_quality_category_path(@quality.quality_category)) }
          end
        end
        div(class: "definition-grid") do
          section(class: "admin-detail-section") do
            h2 { t(:definition) }
            p { @quality.match_rule.presence || t(:not_stored) }
          end
          section(class: "admin-detail-section") do
            h2 { t(:exclusions) }
            p { @quality.not_sufficient.presence || t(:not_stored) }
          end
        end
        section(class: "admin-detail-section") do
          section_heading(:associated_films, count: @films.total)
          render ::Admin::Films::Collection.new(page: @films)
          pagination(@films, path: admin_quality_path(@quality))
        end
      end
    end
  end
end

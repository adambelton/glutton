module Views
  module Registry
    class QualityDetail < Base
      def initialize(detail:)
        @quality, @films = detail.quality, detail.films
      end

      def view_template
        shell(title: @quality.name, active: :qualities, description: t(:quality_description)) do
          a(href: registry_qualities_path, class: "back-link") { t(:all_qualities) }
          p(class: "quality-category") do
            record_link(@quality.quality_category.name, registry_quality_category_path(@quality.quality_category))
          end
          div(class: "definition-grid") do
            section(class: "registry-panel prose-panel") do
              h2 { t(:definition) }
              p { @quality.match_rule.presence || t(:not_stored) }
            end
            section(class: "registry-panel prose-panel") do
              h2 { t(:exclusions) }
              p { @quality.not_sufficient.presence || t(:not_stored) }
            end
          end
          section(class: "registry-panel") do
            section_heading(:associated_films, count: @films.total)
            film_table(@films)
            pagination(@films, path: registry_quality_path(@quality))
          end
        end
      end
    end
  end
end

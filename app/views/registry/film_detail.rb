module Views
  module Registry
    class FilmDetail < Base
      def initialize(detail:)
        @film, @associations = detail.film, detail.associations
      end

      def view_template
        shell(title: @film.title, active: :films, description: t(:film_description)) do
          a(href: registry_films_path, class: "back-link") { t(:all_films) }
          dl(class: "registry-facts") do
            field(:release_date, @film.release_date && I18n.l(@film.release_date, format: :long))
            field(:tmdb_id, @film.tmdb_id&.to_s)
            field(:wikidata_id, @film.wikidata_id)
            field(:source_status, @film.has_source_context? ? t(:source_available) : t(:source_incomplete))
          end
          div(class: "film-detail-grid") do
            section(class: "registry-panel") do
              section_heading(:accepted_qualities, count: @associations.total)
              p(class: "section-note") { t(:accepted_explanation) }
              if @associations.entries.empty?
                empty(:no_qualities)
              else
                @associations.entries.group_by { |association| association.quality.quality_category }.each do |category, associations|
                  div(class: "association-group") do
                    h3 { record_link(category.name, registry_quality_category_path(category)) }
                    associations.each do |association|
                      div(class: "accepted-quality") do
                        record_link(association.quality.name, registry_quality_path(association.quality))
                        render ::Registry::AssociationEvidence.new(association:)
                      end
                    end
                  end
                end
              end
              pagination(@associations, path: registry_film_path(@film))
            end
            div(class: "film-sources") do
              section(class: "registry-panel prose-panel") do
                h2 { t(:metadata) }
                details(class: "source-disclosure") do
                  summary { t(:metadata_spoilers) }
                  metadata
                end
              end
              section(class: "registry-panel prose-panel") do
                h2 { t(:wikipedia) }
                details(class: "source-disclosure") do
                  summary { t(:context_spoilers) }
                  if @film.wikipedia_context.empty?
                    empty(:no_context)
                  else
                    render ::Registry::SourceContext.new(context: @film.wikipedia_context)
                  end
                end
              end
            end
          end
        end
      end

      private

      def metadata
        data = @film.tmdb_details
        if @film.tmdb_metadata.fetch("details", {}).blank?
          empty(:no_metadata)
          return
        end
        p(class: "source-attribution") { t(:tmdb_attribution) }
        if @film.tmdb_id
          a(href: "https://www.themoviedb.org/movie/#{@film.tmdb_id}", class: "back-link", rel: "noreferrer") { t(:view_tmdb) }
        end
        dl(class: "metadata-fields") do
          field(:original_title, data.original_title)
          field(:tagline, data.tagline)
          field(:overview, data.overview)
          field(:runtime, data.runtime && t(:minutes, count: data.runtime))
          field(:original_language, data.original_language)
          field(:status, data.status)
          field(:imdb_id, data.imdb_id)
          field(:genres, data.genre_names.join(", "))
          field(:production_companies, data.production_company_names.join(", "))
          field(:production_countries, data.production_country_names.join(", "))
          field(:spoken_languages, data.spoken_language_names.join(", "))
        end
      end
    end
  end
end

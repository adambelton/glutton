module Admin
  module Films
    class Item < CatalogueComponent
      def initialize(detail:)
        @film, @associations = detail.film, detail.associations
      end

      def view_template
        p(class: "admin-detail-description") { t(:film_description) }
        section(class: "admin-detail-section", aria: { labelledby: "film-details-heading" }) do
          h2(id: "film-details-heading") { t(:film_details) }
          dl(class: "admin-facts") do
            field(:release_date, @film.release_date && I18n.l(@film.release_date, format: :long))
            field(:tmdb_id, @film.tmdb_id&.to_s)
            field(:wikidata_id, @film.wikidata_id)
            field(:source_status, @film.has_source_context? ? t(:source_available) : t(:source_incomplete))
          end
        end
        div(class: "film-detail-grid") do
          section(class: "admin-detail-section") do
            section_heading(:accepted_qualities, count: @associations.total)
            p(class: "section-note") { t(:accepted_explanation) }
            if @associations.entries.empty?
              empty(:no_qualities)
            else
              @associations.entries.group_by { |association| association.quality.quality_category }.each do |category, associations|
                div(class: "association-group") do
                  h3 { record_link(category.name, admin_quality_category_path(category)) }
                  associations.each do |association|
                    div(class: "accepted-quality") do
                      record_link(association.quality.name, admin_quality_path(association.quality))
                      render AssociationEvidence.new(association:)
                    end
                  end
                end
              end
            end
            pagination(@associations, path: admin_film_path(@film))
          end
          div(class: "film-sources") do
            section(class: "admin-detail-section") do
              h2 { t(:metadata) }
              details(class: "source-disclosure") do
                summary { t(:metadata_spoilers) }
                metadata
              end
            end
            section(class: "admin-detail-section") do
              h2 { t(:wikipedia) }
              details(class: "source-disclosure") do
                summary { t(:context_spoilers) }
                if @film.wikipedia_context.empty?
                  empty(:no_context)
                else
                  render SourceContext.new(context: @film.wikipedia_context)
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

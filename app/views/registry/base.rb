module Views
  module Registry
    class Base < ::Views::Base
      private

      def t(key, **options)
        I18n.t("registry.#{key}", **options, raise: true)
      end

      def shell(title: t(:title), active: nil, description: nil)
        page(title:, class: "registry-page", heading_outside_card: true) do
          p(class: "registry-description") { description } if description.present?
          if active.present?
            nav(class: "registry-tabs", aria: { label: t(:navigation) }) do
              { films: registry_films_path, categories: registry_quality_categories_path, qualities: registry_qualities_path }.each do |key, path|
                a(href: path, aria: { current: active == key ? "page" : nil }) { t(key) }
              end
            end
          end
          yield
          p(class: "registry-footer") { t(:read_only) } if active.present?
        end
      end

      def badge(text)
        render RubyUI::Badge.new(variant: :outline, class: "registry-badge") { text }
      end

      def record_link(text, path)
        a(href: path, class: "record-link") { text }
      end

      def empty(message = :empty)
        p(class: "empty-state") { t(message) }
      end

      def table(headers, caption:, &block)
        render RubyUI::Table.new(scroll_label: caption, class: "registry-table") do
          render RubyUI::TableCaption.new(class: "sr-only") { caption }
          render RubyUI::TableHeader.new do
            render RubyUI::TableRow.new do
              headers.each do |key|
                render RubyUI::TableHead.new(scope: "col") { t(key) }
              end
            end
          end
          render RubyUI::TableBody.new(&block)
        end
      end

      def cell(&block)
        render RubyUI::TableCell.new(&block)
      end

      def pagination(page, path:)
        nav(class: "registry-pagination", aria: { label: t(:pagination) }) do
          p { t(:page, number: page.number, total: [ (page.total.to_f / ::Registry::CatalogueQueries::InspectCatalogue::PAGE_SIZE).ceil, 1 ].max) }
          div do
            if page.number > 1
              render RubyUI::Link.new(href: "#{path}?page=#{page.number - 1}", variant: :ghost, class: "min-h-11") { t(:previous) }
            end
            if page.next_page
              render RubyUI::Link.new(href: "#{path}?page=#{page.number + 1}", variant: :ghost, class: "min-h-11") { t(:next) }
            end
          end
        end
      end

      def section_heading(key, count: nil)
        div(class: "section-heading") do
          h2 { t(key) }
          badge(t(:records, count:)) unless count.nil?
        end
      end

      def field(key, value)
        div do
          dt { t(key) }
          dd { value.presence || t(:not_stored) }
        end
      end

      def film_table(page)
        if page.entries.empty?
          empty
        else
          table([ :film, :release_date, :tmdb_id ], caption: t(:films)) do
            page.entries.each do |film|
              render RubyUI::TableRow.new do
                cell { record_link(film.title, registry_film_path(film)) }
                cell { film.release_date ? I18n.l(film.release_date, format: :long) : t(:not_stored) }
                cell { film.tmdb_id || t(:not_stored) }
              end
            end
          end
        end
      end

      def quality_table(page, category: true)
        if page.entries.empty?
          empty
        else
          headers = category ? [ :quality, :category, :definition ] : [ :quality, :definition ]
          table(headers, caption: t(:qualities)) do
            page.entries.each do |quality|
              render RubyUI::TableRow.new do
                cell { record_link(quality.name, registry_quality_path(quality)) }
                cell { record_link(quality.quality_category.name, registry_quality_category_path(quality.quality_category)) } if category
                cell { p(class: "definition-preview") { quality.match_rule.presence || t(:not_stored) } }
              end
            end
          end
        end
      end
    end
  end
end

module Admin
  class CatalogueComponent < Shared::Base
    private

    def t(key, **options)
      I18n.t("registry.#{key}", **options, raise: true)
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
      render RubyUI::Table.new(scroll_label: caption, class: "admin-table ui-collection-table registry-table") do
        render RubyUI::TableCaption.new(class: "sr-only") { caption }
        render RubyUI::TableHeader.new do
          render RubyUI::TableRow.new do
            headers.each do |key|
              render Shared::TableCell.new(heading: true) { t(key) }
            end
          end
        end
        render RubyUI::TableBody.new(&block)
      end
    end

    def cell(&block)
      render Shared::TableCell.new(&block)
    end

    def pagination(page, path:)
      render Pagination.new(page:, path:)
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
  end
end

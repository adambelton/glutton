module Shared
  class FilmSearchPagination < Base
    def initialize(page:, total: nil, previous: nil, next_page: nil, page_attributes: {})
      @page, @total, @previous, @next_page = page, total, previous, next_page
      @page_attributes = page_attributes
    end

    def view_template
      nav(class: "film-search-pagination", aria: { label: t("ui.search.pagination.label") }) do
        control(:previous, @previous) if @previous.present?
        span(**@page_attributes) do
          if @total.present?
            t("ui.search.pagination.page", number: @page, total: @total)
          else
            t("ui.search.pagination.current_page", number: @page)
          end
        end
        control(:next, @next_page) if @next_page.present?
      end
    end

    private

    def control(direction, attributes)
      label = t("ui.search.pagination.#{direction}")
      if attributes.key?(:href)
        render RubyUI::Link.new(class: "ui-link", **attributes) { label }
      else
        render RubyUI::Button.new(type: :button, variant: :link, class: "ui-link", **attributes) { label }
      end
    end
  end
end

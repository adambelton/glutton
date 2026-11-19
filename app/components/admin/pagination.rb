module Admin
  class Pagination < Shared::Base
    def initialize(page:, path:, query: "", private_search: false, show_count: false, frame: nil)
      @page, @path, @query, @private_search, @show_count = page, path, query, private_search, show_count
      @frame = frame
    end

    def view_template
      nav(class: "admin-pagination", aria: { label: t("admin.pagination.label") }) do
        div(class: "admin-page-summary") do
          p { t("admin.pagination.page", number: @page.number, total: @page.total_pages) }
          p { t("admin.pagination.records", count: @page.total) } if @show_count
        end
        div(class: "admin-page-links") do
          page_link(:previous, @page.number - 1) if @page.number > 1
          page_link(:next, @page.number + 1) if @page.number < @page.total_pages
        end
      end
    end

    private

    def page_link(direction, number)
      label = t("admin.pagination.#{direction}")
      if @private_search && @query.present?
        form_with(url: @path, method: :post, data: { turbo_frame: @frame }) do
          input(type: "hidden", name: "page", value: number)
          input(type: "hidden", name: "account_email_or_id", value: @query)
          render Shared::GhostButton.new(type: :submit) { label }
        end
      else
        params = { page: number }
        params[:q] = @query if @query.present?
        render RubyUI::Link.new(href: "#{@path}?#{params.to_query}", variant: :ghost, class: "min-h-11") { label }
      end
    end
  end
end

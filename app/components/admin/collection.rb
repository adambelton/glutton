module Admin
  class Collection < Shared::Base
    def initialize(page:, path:, label:, query:, private_search: false)
      @page, @path, @label, @query, @private_search = page, path, label, query, private_search
    end

    def view_template
      div(class: "admin-collection") do
        search_form
        if @query.present? && @page.entries.empty?
          p(class: "admin-search-empty", role: "status") { t("admin.search.no_matches") }
        else
          yield
        end
        render Pagination.new(page: @page, path: @path, query: @query, private_search: @private_search, show_count: true)
      end
    end

    private

    def search_form
      form_with(url: @path, method: (@private_search ? :post : :get), class: "admin-search",
        data: ({ turbo: false } if @private_search)) do
        div(class: "admin-search-controls") do
          div(class: "admin-search-field") do
            input(type: "search", id: "admin-collection-query", name: (@private_search ? "account_email_or_id" : "q"),
              value: @query, placeholder: @label, aria: { label: @label }, maxlength: 254, autocomplete: "off", class: "ui-input")
            if @query.present?
              a(href: @path, class: "admin-clear-search", title: t("admin.search.clear"), aria: { label: t("admin.search.clear") }) do
                span(aria: { hidden: "true" }) { "×" }
              end
            end
          end
          render RubyUI::Button.new(type: :submit) { t("admin.search.submit") }
        end
      end
    end
  end
end

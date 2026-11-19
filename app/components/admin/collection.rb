module Admin
  class Collection < Shared::Base
    RESULTS_FRAME = "admin-collection-results"

    def initialize(page:, path:, label:, query:, private_search: false, companion: nil)
      @page, @path, @label, @query, @private_search = page, path, label, query, private_search
      @companion = companion
    end

    def view_template
      div(class: "admin-collection", data: { controller: "admin-collection-search",
        action: "turbo:frame-load->admin-collection-search#updateLocation" }) do
        if @companion.present?
          div(class: "admin-collection-searches") do
            search_form
            render @companion
          end
        else
          search_form
        end
        tag(:turbo_frame, id: RESULTS_FRAME, target: "_top", aria: { live: "polite" },
          data: { admin_collection_search_target: "results" }) do
          if @query.present? && @page.entries.empty?
            p(class: "admin-search-empty", role: "status") { t("admin.search.no_matches") }
          else
            yield
          end
          render Pagination.new(page: @page, path: @path, query: @query, private_search: @private_search,
            show_count: true, frame: RESULTS_FRAME)
        end
      end
    end

    private

    def search_form
      form_with(url: @path, method: (@private_search ? :post : :get), class: "admin-search", role: "search",
        data: { admin_collection_search_target: "form", turbo_frame: RESULTS_FRAME,
          action: "submit->admin-collection-search#submit" }) do
        div(class: "admin-search-field") do
          input(type: "search", id: "admin-collection-query", name: (@private_search ? "account_email_or_id" : "q"),
            value: @query, placeholder: @label, aria: { label: @label, controls: RESULTS_FRAME }, maxlength: 254,
            autocomplete: "off", class: "ui-input", data: { admin_collection_search_target: "input",
              action: "input->admin-collection-search#schedule compositionend->admin-collection-search#schedule keydown.esc->admin-collection-search#escape" })
          a(href: @path, class: "admin-clear-search", hidden: @query.blank?, title: t("admin.search.clear"),
            aria: { label: t("admin.search.clear") }, data: { admin_collection_search_target: "clearLink",
              action: "click->admin-collection-search#clear", turbo_frame: RESULTS_FRAME }) do
            span(aria: { hidden: "true" }) { "×" }
          end
        end
      end
    end
  end
end

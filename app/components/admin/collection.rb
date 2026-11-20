module Admin
  class Collection < Shared::Base
    RESULTS_FRAME = "admin-collection-results"

    def initialize(page:, query:, search:, pagination:)
      @page, @query, @search, @pagination = page, query, search, pagination
    end

    def view_template
      div(class: "admin-collection") do
        render @search
        tag(:turbo_frame, id: RESULTS_FRAME, target: "_top", aria: { live: "polite" }) do
          if @query.present? && @page.entries.empty?
            p(class: "admin-search-empty", role: "status") { t("admin.search.no_matches") }
          else
            yield
          end
          render @pagination
        end
      end
    end
  end
end

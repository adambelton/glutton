module Shared
  class CollectionSearchForm < Base
    def initialize(path:, clear_path:, label:, query:, input_id:, frame:, context: [], method: :get, parameter: "q", css_class: nil)
      @path, @clear_path, @context, @label, @query = path, clear_path, context, label, query
      @input_id, @frame, @method, @parameter, @css_class = input_id, frame, method, parameter, css_class
    end

    def view_template
      form_with(url: @path, method: @method, class: @css_class, role: "search",
        data: { controller: "collection-search", turbo_frame: @frame,
          action: "submit->collection-search#submit turbo:frame-load@document->collection-search#updateLocation" }) do
        @context.each { |name, value| input(type: "hidden", name:, value:) }
        div(class: "collection-search-field") do
          input(type: "search", id: @input_id, name: @parameter,
            value: @query, placeholder: @label, aria: { label: @label, controls: @frame }, maxlength: CollectionSearchParameters::MAX_QUERY_LENGTH,
            autocomplete: "off", class: "ui-input", data: { collection_search_target: "input",
              action: "input->collection-search#schedule compositionend->collection-search#schedule keydown.esc->collection-search#escape" })
          label = t("ui.search.clear")
          a(href: @clear_path, class: "collection-search-clear", hidden: @query.blank?, title: label, aria: { label: },
            data: { collection_search_target: "clearLink", action: "click->collection-search#clear", turbo_frame: @frame }) do
            span(aria: { hidden: "true" }) { "×" }
          end
        end
      end
    end
  end
end

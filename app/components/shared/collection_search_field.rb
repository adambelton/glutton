module Shared
  class CollectionSearchField < Base
    def initialize(label:, controls:, input_data:, clear_data:, query: "", input_id: nil, name: nil, description_id: nil,
      clear_path: nil, placeholder: label, clear_label: "ui.search.clear", maxlength: CollectionSearchParameters::MAX_QUERY_LENGTH,
      required: false, loading: nil)
      @input_id, @label, @controls, @query, @name = input_id, label, controls, query, name
      @description_id, @input_data, @clear_data, @clear_path = description_id, input_data, clear_data, clear_path
      @placeholder, @clear_label, @maxlength, @required = placeholder, clear_label, maxlength, required
      @loading = loading
    end

    def view_template
      div(class: "collection-search-field") do
        if @loading.present?
          span(class: "ui-spinner collection-search-spinner", role: "status", hidden: true, data: @loading.fetch(:data)) do
            span(class: "sr-only") { @loading.fetch(:label) }
          end
        end
        input(type: "search", id: @input_id, name: @name, value: @query, placeholder: @placeholder, required: @required,
          aria: { label: @label, controls: @controls, describedby: @description_id },
          maxlength: @maxlength, autocomplete: "off", class: "ui-input", data: @input_data)
        clear_control
      end
    end

    private

    def clear_control
      label = t(@clear_label)
      element, attributes = @clear_path.present? ? [ :a, { href: @clear_path } ] : [ :button, { type: :button } ]
      tag(element, **attributes, class: "collection-search-clear", hidden: @query.blank?, title: label,
        aria: { label: }, data: @clear_data) do
        span(aria: { hidden: "true" }) { "×" }
      end
    end
  end
end

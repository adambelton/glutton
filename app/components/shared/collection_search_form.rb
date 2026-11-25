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
        render CollectionSearchField.new(input_id: @input_id, label: @label, controls: @frame,
          name: @parameter, query: @query, clear_path: @clear_path,
          input_data: { collection_search_target: "input",
            action: "input->collection-search#schedule compositionend->collection-search#schedule keydown.esc->collection-search#escape" },
          clear_data: { collection_search_target: "clearLink", action: "click->collection-search#clear", turbo_frame: @frame })
      end
    end
  end
end

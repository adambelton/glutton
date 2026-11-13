module Shared
  class ActionForm < Base
    def initialize(url:, method: :post, params: {}, data: {})
      @url = url
      @method = method
      @params = params
      @data = data
    end

    def view_template
      form_with(url: @url, method: @method, class: "ui-action-form", data: @data) do
        @params.each { |key, value| input(type: "hidden", name: key.to_s, value:) }
        yield
      end
    end
  end
end

module Shared
  class ActionForm < Base
    def initialize(url:, method: :post, params: {}, data: {}, readonly: false)
      @url = url
      @method = method
      @params = params
      @data = data
      @readonly = readonly
    end

    def view_template(&block)
      if @readonly
        div(class: "ui-action-form", &block)
      else
        form_with(url: @url, method: @method, class: "ui-action-form", data: @data) do
          @params.each { |key, value| input(type: "hidden", name: key.to_s, value:) }
          yield
        end
      end
    end
  end
end

module Shared
  class ActionButton < Base
    def initialize(text:, url:, method: :post, params: {}, **attrs)
      @text, @url, @method, @params, @attrs = text, url, method, params, attrs
    end

    def view_template
      form_with(url: @url, method: @method, class: "ui-action-form") do
        @params.each { |key, value| input(type: "hidden", name: key.to_s, value:) }
        render RubyUI::Button.new(type: :submit, variant: :outline, class: "ui-action-button", **@attrs) { @text }
      end
    end
  end
end

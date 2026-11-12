module Shared
  class ActionButton < Base
    def initialize(text:, url:, method: :post, variant: :outline, params: {}, icon: nil, **attrs)
      @text, @url, @method, @params, @attrs = text, url, method, params, attrs
      @icon, @variant = icon, variant
    end

    def view_template
      form_with(url: @url, method: @method, class: "ui-action-form") do
        @params.each { |key, value| input(type: "hidden", name: key.to_s, value:) }
        icon_attrs = @icon.present? ? { icon: true, size: :xl, data: { tooltip: @text }, aria: { label: @text } } : {}
        render RubyUI::Button.new(type: :submit, variant: @variant, class: "ui-action-button", **icon_attrs, **@attrs) do
          @icon.present? ? render(@icon) : plain(@text)
        end
      end
    end
  end
end

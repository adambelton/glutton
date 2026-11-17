module Library
  class CardAction < Shared::Base
    def initialize(label:, tooltip:, url: nil, method: :post, params: {}, readonly: false, **attrs)
      @label, @tooltip, @url, @method, @params, @readonly, @attrs = label, tooltip, url, method, params, readonly, attrs
    end

    def view_template(&block)
      if @readonly
        div(class: "ui-action-form") { action_button(&block) }
      else
        render Shared::ActionForm.new(url: @url, method: @method, params: @params) { action_button(&block) }
      end
    end

    private

    def action_button(&block)
      render Shared::IconButton.new(type: :submit, variant: :ghost, size: :xl, class: "ui-action-button",
        disabled: @readonly, aria: { label: @label }, data: { tooltip: (@tooltip unless @readonly) }, **@attrs), &block
    end
  end
end

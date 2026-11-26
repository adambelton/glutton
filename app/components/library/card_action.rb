module Library
  class CardAction < Shared::Base
    def initialize(label:, tooltip:, url: nil, method: :post, params: {}, readonly: false, in_collection: false, film_title: nil, **attrs)
      @label, @tooltip, @url, @method, @params, @readonly, @attrs = label, tooltip, url, method, params, readonly, attrs
      @in_collection = in_collection
      @film_title = film_title
    end

    def view_template(&block)
      if @readonly
        div(class: "ui-action-form") { action_button(&block) }
      elsif @url.present? && @film_title.present?
        render FilmActionForm.new(url: @url, method: @method, params: @params, action_label: @tooltip, film_title: @film_title) { action_button(&block) }
      elsif @url.present?
        render Shared::ActionForm.new(url: @url, method: @method, params: @params) { action_button(&block) }
      else
        action_button(&block)
      end
    end

    private

    def action_button(&block)
      unavailable = @url.blank? && !@readonly
      render Shared::IconButton.new(type: (unavailable ? :button : :submit), variant: (unavailable ? :plain : :ghost), size: :xl,
        class: "ui-action-button", disabled: @readonly, aria: { label: @label, disabled: ("true" if unavailable) },
        data: { tooltip: (@tooltip unless @readonly), in_collection: ("true" if @in_collection) }, **@attrs), &block
    end
  end
end

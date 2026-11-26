module Library
  class FilmActionForm < Shared::Base
    def initialize(url:, action_label:, film_title:, method: :post, params: {}, data: {}, readonly: false)
      @url, @method, @params, @readonly = url, method, params, readonly
      @data = data.merge(library_confirmation_title: action_label, library_confirmation_film: film_title)
    end

    def view_template(&block)
      render Shared::ActionForm.new(url: @url, method: @method, params: @params, data: @data, readonly: @readonly), &block
    end
  end
end

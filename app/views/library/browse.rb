module Views
  module Library
    class Browse < ::Views::Base
      def initialize(view:, page:, page_number:, ratings:)
        @view, @page, @page_number, @ratings = view, page, page_number, ratings
      end

      def view_template
        page(title: t("library.browser.title"), class: "library-page", heading_outside_card: true,
          heading_action: ::Library::FilmSearchForm.new(dropdown: true)) do
          render ::Library::Collection.new(view: @view, page: @page, page_number: @page_number, ratings: @ratings)
        end
      end
    end
  end
end

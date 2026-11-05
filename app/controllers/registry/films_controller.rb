module Registry
  class FilmsController < BaseController
    def index
      render ::Views::Registry::FilmsIndex.new(page: InspectCatalogue.films(page: @page_number))
    end

    def show
      render ::Views::Registry::FilmDetail.new(detail: InspectCatalogue.film(id: params[:id], page: @page_number))
    end
  end
end

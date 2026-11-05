module Registry
  class QualitiesController < BaseController
    def index
      render ::Views::Registry::QualitiesIndex.new(page: InspectCatalogue.qualities(page: @page_number))
    end

    def show
      render ::Views::Registry::QualityDetail.new(detail: InspectCatalogue.quality(id: params[:id], page: @page_number))
    end
  end
end

module Registry
  class BaseController < ApplicationController
    before_action :require_superuser

    rescue_from Identity::Errors::Required do
      redirect_to new_session_path
    end

    rescue_from ActiveRecord::RecordNotFound do
      render ::Views::Admin::Message.new(key: :not_found), status: :not_found
    end

    private

    def require_superuser
      unless current_user.superuser?
        render ::Views::Admin::Message.new(key: :forbidden), status: :forbidden
      end
    end

    def catalogue_search_parameters
      CollectionSearchParameters.parse(query: params.fetch(:q, ""), page: params.fetch(:page, "1"), max_digits: 6)
    end

    def catalogue_context(search)
      { q: search.query.presence, page: (search.page if search.page > 1) }.compact
    end

    def catalogue_page_number
      CollectionSearchParameters.page(params.fetch(:page, "1"), max_digits: 6)
    end

    def catalogue_record_id
      id = params[:id]
      raise ActiveRecord::RecordNotFound unless id.is_a?(String) && id.match?(/\A[1-9]\d{0,17}\z/)

      id
    end

    def render_invalid_parameters
      render ::Views::Admin::Message.new(key: :invalid), status: :bad_request
    end
  end
end

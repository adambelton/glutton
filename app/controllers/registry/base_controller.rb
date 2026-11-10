module Registry
  class BaseController < ApplicationController
    before_action :require_superuser
    before_action :validate_browsing_parameters

    rescue_from Identity::Errors::Required do
      redirect_to new_session_path
    end

    rescue_from ActiveRecord::RecordNotFound do
      render ::Views::Registry::Message.new(key: :not_found), status: :not_found
    end

    private

    def require_superuser
      unless current_user.superuser?
        render ::Views::Registry::Message.new(key: :forbidden), status: :forbidden
      end
    end

    def validate_browsing_parameters
      page = params.fetch(:page, "1")
      unless page.is_a?(String) && page.match?(/\A[1-9]\d{0,5}\z/)
        render ::Views::Registry::Message.new(key: :invalid), status: :bad_request
        return
      end
      @page_number = page.to_i
      if params.key?(:id) && !(params[:id].is_a?(String) && params[:id].match?(/\A[1-9]\d{0,17}\z/))
        raise ActiveRecord::RecordNotFound
      end
    end
  end
end

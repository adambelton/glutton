module Community
  class CodeOfConductController < ApplicationController
    allow_unauthenticated_access only: :show

    def show
      code = params.key?(:version) ? CodeOfConduct.find(params[:version]) : CodeOfConduct.current
      return head :not_found unless code.present?

      render Views::Community::CodeOfConduct.new(code:)
    end
  end
end

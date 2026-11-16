class TermsOfServiceController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    terms = params.key?(:version) ? Identity::TermsOfService.find(params[:version]) : Identity::TermsOfService.current
    return head :not_found unless terms.present?

    render ::Views::Identity::TermsOfService.new(terms:)
  end
end

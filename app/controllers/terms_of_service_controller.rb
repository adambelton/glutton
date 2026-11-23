class TermsOfServiceController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    render ::Views::Identity::TermsOfService.new(terms: Identity::TermsOfService.current)
  end
end

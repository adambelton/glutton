class TermsOfServiceController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    render ::Views::Identity::TermsOfService.new
  end
end

class PrivacyNoticesController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    render ::Views::Identity::PrivacyNotice.new(notice: Identity::PrivacyNotice.current)
  end
end

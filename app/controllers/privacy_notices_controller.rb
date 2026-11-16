class PrivacyNoticesController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    notice = params.key?(:version) ? Identity::PrivacyNotice.find(params[:version]) : Identity::PrivacyNotice.current
    return head :not_found unless notice.present?

    render ::Views::Identity::PrivacyNotice.new(notice:)
  end
end

module Community
  class PublicProfilesController < ApplicationController
    rescue_from Errors::MembershipRequired, with: -> { head :forbidden }
    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

    def show
      id = params[:id]
      return head :bad_request unless RecordId.valid?(id)

      page = Membership::ReadPublicProfile.for_display(id:, viewer: current_user)
      render Views::Community::PublicProfile.new(**page.to_h)
    end
  end
end

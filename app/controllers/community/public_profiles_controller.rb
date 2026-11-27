module Community
  class PublicProfilesController < ApplicationController
    rescue_from Errors::MembershipRequired, with: -> { head :forbidden }
    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

    def show
      id = params[:id]
      return head :bad_request unless RecordId.valid?(id)

      community_user = Membership::ReadPublicProfile.call(id:, viewer: current_user)
      can_suspend = Moderation::Access.review?(user: current_user) && Membership::Access.participation_allowed?(user: community_user.user)
      render Views::Community::PublicProfile.new(community_user:, can_suspend:)
    end
  end
end

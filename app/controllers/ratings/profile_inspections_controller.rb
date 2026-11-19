module Ratings
  class ProfileInspectionsController < ApplicationController
    before_action :require_superuser

    rescue_from Identity::Errors::Unavailable do
      head :not_found
    end

    def show
      id = params[:id]
      return head :not_found unless id.is_a?(String) && id.match?(/\A[1-9]\d{0,17}\z/)

      user_id = id.to_i
      profile = TasteProfiling::ViewTasteProfile.inspect_saved(user_id:)
      render ::Views::Admin::Users::Profile.new(user_id:, profile:)
    end

    private

    def require_superuser
      head :forbidden unless current_user.superuser?
    end
  end
end

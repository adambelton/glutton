module Community
  class ModerationController < ApplicationController
    def show
      return head :forbidden unless Moderation::Access.review?(user: current_user)

      render Views::Community::Moderation.new
    end
  end
end

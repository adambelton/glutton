class AdminController < ApplicationController
  def show
    return head :forbidden unless current_user.superuser?

    redirect_to admin_users_path
  end
end

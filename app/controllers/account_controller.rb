class AccountController < ApplicationController
  before_action :require_account_access
  before_action :require_superuser, only: :refresh_taste_profile

  def show
    render Views::Account::Show.new(profile: Ratings::TasteProfiling::ViewTasteProfile.call(user_id: current_user.id),
      can_refresh_taste_profile: current_user.superuser?)
  end

  def refresh_taste_profile
    job = Ratings::RefreshTasteProfilesJob.new(current_user.id)
    if job.enqueue
      redirect_to account_taste_profile_path, status: :see_other, notice: t("account.refresh_queued")
    elsif job.enqueue_error.present?
      redirect_to account_taste_profile_path, status: :see_other, alert: t("account.refresh_failed")
    else
      redirect_to account_taste_profile_path, status: :see_other, notice: t("account.refresh_already_queued")
    end
  rescue ActiveJob::EnqueueError
    redirect_to account_taste_profile_path, status: :see_other, alert: t("account.refresh_failed")
  end

  private

  def require_account_access
    response.headers["Cache-Control"] = "no-store"
    head :forbidden unless current_user.can_view_account?
  end

  def require_superuser
    head :forbidden unless current_user.superuser?
  end
end

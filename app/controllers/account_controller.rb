class AccountController < ApplicationController
  before_action :require_superuser

  def show
    render Views::Account::Show.new(profile: Ratings::TasteProfiling::ViewTasteProfile.call(user_id: current_user.id))
  end

  def refresh_taste_profile
    job = Ratings::RefreshTasteProfilesJob.new(current_user.id)
    if job.enqueue
      redirect_to account_path, status: :see_other, notice: t("account.refresh_queued")
    elsif job.enqueue_error.present?
      redirect_to account_path, status: :see_other, alert: t("account.refresh_failed")
    else
      redirect_to account_path, status: :see_other, notice: t("account.refresh_already_queued")
    end
  rescue ActiveJob::EnqueueError
    redirect_to account_path, status: :see_other, alert: t("account.refresh_failed")
  end

  private

  def require_superuser
    response.headers["Cache-Control"] = "no-store"
    head :forbidden unless current_user.superuser?
  end
end

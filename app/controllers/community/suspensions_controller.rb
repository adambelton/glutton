module Community
  class SuspensionsController < ApplicationController
    rescue_from Errors::ModerationAccessDenied, with: -> { head :forbidden }
    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
    rescue_from Errors::SuspensionUnavailable do
      redirect_to community_suspensions_path, alert: t("community.suspensions.changed"), status: :see_other
    end

    def index
      search = CollectionSearchParameters.parse(query: "", page: params.fetch(:page, "1"), max_digits: 6)
      suspension_state = params.fetch(:state, "active")
      return head :bad_request unless search.present? && %w[active lifted].include?(suspension_state)

      queue_page = Moderation::ManageSuspensions.browse(viewer: current_user, number: search.page, state: suspension_state)
      return redirect_to community_suspensions_path(state: suspension_state) if search.page > queue_page.total_pages

      render Views::Community::Moderation.new(queue_page:, state: suspension_state)
    end

    def new
      member_id = record_id(params[:member_id])
      report_id = record_id(params[:report_id]) if params.key?(:report_id)
      member = Moderation::ManageSuspensions.target(viewer: current_user, member_id:, report_id:)
      render Views::Community::NewSuspension.new(member:, report_id:)
    end

    def create
      fields = params.expect(suspension: [ :member_id, :report_id ])
      member_id = record_id(fields[:member_id])
      report_id = record_id(fields[:report_id]) if fields.key?(:report_id)
      Moderation::ManageSuspensions.suspend(actor_id: current_user.id, member_id:, report_id:)
      destination = report_id.present? ? community_moderation_report_path(report_id) : community_suspensions_path
      redirect_to destination, notice: t("community.suspensions.started"), status: :see_other
    end

    def lift
      Moderation::ManageSuspensions.lift(actor_id: current_user.id, suspension_id: record_id(params[:id]))
      redirect_to community_suspensions_path, notice: t("community.suspensions.lifted"), status: :see_other
    end

    private

    def record_id(value)
      raise ActionController::BadRequest unless RecordId.valid?(value)

      value.to_i
    end
  end
end

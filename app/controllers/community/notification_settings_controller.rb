module Community
  class NotificationSettingsController < ApplicationController
    before_action { response.headers["Referrer-Policy"] = "no-referrer" }

    rescue_from Errors::MembershipRequired, with: -> { head :forbidden }
    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

    def update
      direct_replies = params[:direct_replies]
      authored_curations = params[:authored_curations]
      endorsed_film_comments = params[:endorsed_film_comments]
      rating_values = params.fetch(:rating_values, [])
      return head :bad_request unless %w[0 1].include?(direct_replies) && rating_values.is_a?(Array) && rating_values.all?(String)
      return head :bad_request unless [ authored_curations, endorsed_film_comments ].all? { |value| [ nil, "0", "1" ].include?(value) }

      Notifications::ManageSettings.update(viewer: current_user, rating_values:, direct_replies: direct_replies == "1",
        authored_curations: (authored_curations == "1" unless authored_curations.nil?),
        endorsed_film_comments: (endorsed_film_comments == "1" unless endorsed_film_comments.nil?))
      redirect_to account_community_path(anchor: "notification-settings"), notice: t("community.notifications.saved"), status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      page = Membership::ReadProfileSettings.call(viewer: current_user)
      render Views::Community::Profile.new(**page.to_h, notification_errors: error.record.errors.full_messages), status: :unprocessable_content
    end

    def debrief
      following = params[:following]
      return head :bad_request unless %w[0 1].include?(following)

      Notifications::ManageSettings.update_debrief_post_preference(viewer: current_user, post_id: params[:post_id], following: following == "1")
      redirect_to community_post_path(params[:post_id], anchor: "debrief-notifications"),
        notice: t("community.notifications.saved"), status: :see_other
    end

    def curation
      following = params[:following]
      post_id = params[:post_id]
      film_id = request.path_parameters[:film_id]
      return head :bad_request unless %w[0 1].include?(following) &&
        RecordId.valid?(post_id) && (film_id.nil? || RecordId.valid?(film_id))

      Notifications::ManageSettings.update_curation_preference(viewer: current_user, post_id: post_id.to_i,
        film_id: film_id&.to_i, following: following == "1")
      anchor = film_id.present? ? "nomination-#{film_id.to_i}" : "curation-notifications"
      redirect_to community_post_path(post_id, anchor:), notice: t("community.notifications.saved"), status: :see_other
    end
  end
end

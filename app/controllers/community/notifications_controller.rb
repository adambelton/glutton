module Community
  class NotificationsController < ApplicationController
    before_action { response.headers["Referrer-Policy"] = "no-referrer" }

    rescue_from Errors::MembershipRequired, with: -> { head :forbidden }
    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

    def index
      before = params[:before]
      if before.present?
        return head :bad_request unless before.is_a?(String) && before.match?(/\A[1-9]\d{0,18}\z/)

        before = Integer(before, 10)
      end
      page = Notifications::Inbox.new(viewer: current_user).page(before:)
      render Views::Community::NotificationsInbox.new(**page.to_h)
    end

    def open
      comment = Notifications::Inbox.new(viewer: current_user).open!(id: params[:id])
      redirect_to community_post_path(comment.post_id, reply: comment.id, anchor: "comment-#{comment.id}"), status: :see_other
    end
  end
end

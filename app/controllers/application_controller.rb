class ApplicationController < ActionController::Base
  include Identity::UserSessions
  include Identity::EntryNavigation
  include Identity::Authentication
  layout false

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  prepend_around_action :filter_routine_activity

  stale_when_importmap_changes

  private

  def filter_routine_activity
    yield
    if (request.get? || request.head?) && response.status < 400 && !@business_activity
      ActivityMonitoring.ignore_routine_activity
    end
  end
end

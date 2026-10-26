class ApplicationController < ActionController::Base
  include Identity::UserSessions

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def require_identity
    raise Identity::Required unless current_user
  end
end

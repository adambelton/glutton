class ApplicationController < ActionController::Base
  include Identity::UserSessions
  include Identity::EntryNavigation
  include Identity::Authentication
  layout false

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end

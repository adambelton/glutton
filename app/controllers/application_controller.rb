class ApplicationController < ActionController::Base
  include Identity::UserSessions
  include Identity::EntryNavigation
  include Identity::Authentication
  layout false

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  prepend_around_action :trace_request

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def trace_request
    ActivityMonitoring.trace("#{self.class.name}##{action_name}", parent: nil, kind: :server,
      attributes: { "http.request.method" => request.request_method, "request.id" => request.request_id }) do
      yield
      span = ActivityMonitoring.current
      span&.set_attribute("http.response.status_code", response.status)
      span.status = OpenTelemetry::Trace::Status.error if span && response.server_error?
    end
  end
end

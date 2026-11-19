module Monitoring
  module RequestTracing
    extend ActiveSupport::Concern

    included do
      prepend_around_action :trace_request
    end

    private

    def trace_request
      attributes = {
        OpenTelemetry::SemConv::HTTP::HTTP_REQUEST_METHOD => request.request_method,
        ActivityMonitoring::Attributes::REQUEST_ID => request.request_id
      }
      ActivityMonitoring.trace("#{self.class.name}##{action_name}", parent: nil, kind: :server, attributes:) do
        yield
        span = ActivityMonitoring.current
        span&.set_attribute(OpenTelemetry::SemConv::HTTP::HTTP_RESPONSE_STATUS_CODE, response.status)
        span.status = OpenTelemetry::Trace::Status.error if span && response.server_error?
      end
    end
  end
end

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
      ActivityMonitoring.trace_business("#{self.class.name}##{action_name}", parent: nil, kind: :server, attributes:) do
        yield
        ActivityMonitoring.current&.set_http_response(response)
      end
    end
  end
end

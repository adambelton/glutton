module Monitoring
  module RequestTracing
    private

    # Rails handles rescue_from outside the action callbacks.
    def process_action(...)
      attributes = {
        OpenTelemetry::SemConv::HTTP::HTTP_REQUEST_METHOD => request.request_method,
        ActivityMonitoring::Attributes::REQUEST_ID => request.request_id
      }
      ActivityMonitoring.trace_operation("#{self.class.name}##{action_name}", parent: nil, kind: :server, attributes:) do |span|
        super.tap { span&.set_http_response(response) }
      end
    end
  end
end

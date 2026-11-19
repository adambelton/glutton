module ActivityMonitoring
  # A Rails notification starts and finishes in separate callbacks. Block-based
  # callers use the same lifecycle, including restoration of the enclosing span.
  class SpanSession
    def initialize(tracer, name, span_class:, parent:, attributes:, links: [], kind: :internal)
      @span = tracer.start_span(name, with_parent: parent, attributes:, links:, kind:)
      @record = span_class.new(@span)
      context = OpenTelemetry::Trace.context_with_span(@span, parent_context: parent)
      @token = OpenTelemetry::Context.attach(context)
    end

    def record
      yield @record
    rescue StandardError => error
      @record.record_failure(error)
      raise
    ensure
      finish
    end

    def finish(error: nil)
      @record.record_failure(error) if error
    ensure
      OpenTelemetry::Context.detach(@token)
      @span.finish
    end
  end
end

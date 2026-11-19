require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"

require "opentelemetry-instrumentation-active_job"

module ActivityMonitoring
  class Exporter < OpenTelemetry::Exporter::OTLP::Exporter
    def export(spans, timeout: nil)
      # Active Job records raw exception messages and stack traces in span events.
      safe_spans = spans.map do |original|
        span = original.dup
        exception_type = Array(original.events).filter_map { |event| event.attributes&.fetch("exception.type", nil) }.first
        if exception_type
          span.attributes = (original.attributes || {}).merge("error.type" => exception_type)
          span.total_recorded_attributes += 1 unless original.attributes&.key?("error.type")
        end
        span.events = nil
        span.status = OpenTelemetry::Trace::Status.error if span.status.code == OpenTelemetry::Trace::Status::ERROR
        span
      end
      super(safe_spans, timeout:)
    end
  end

  class Processor < OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor
    def on_finish(span)
      return unless %w[glutton.business OpenTelemetry::Instrumentation::ActiveJob].include?(span.instrumentation_scope.name)
      scheduled = %w[DispatchDomainEventsJob Ratings::RefreshTasteProfilesJob ReportWorkerHealthJob].include?(span.attributes&.fetch("code.namespace", nil))
      return if scheduled && span.kind == :producer && span.status.code != OpenTelemetry::Trace::Status::ERROR

      super unless span.attributes&.fetch("glutton.routine", false) && span.status.code != OpenTelemetry::Trace::Status::ERROR
    end
  end

  class << self
    attr_accessor :tracer

    def configure
      key = ENV["HONEYCOMB_API_KEY"]
      return if key.blank?

      host = { "eu" => "api.eu1.honeycomb.io", "us" => "api.honeycomb.io" }.fetch(ENV.fetch("HONEYCOMB_REGION"))
      exporter = Exporter.new(endpoint: "https://#{host}/v1/traces",
        headers: { "x-honeycomb-team" => key }, compression: "gzip")
      environment = ENV.fetch("HONEYCOMB_ENVIRONMENT")
      resource = OpenTelemetry::SDK::Resources::Resource.create("service.name" => "glutton-#{environment}",
        "deployment.environment.name" => environment, "service.version" => ENV.fetch("RENDER_GIT_COMMIT", "local"))
      OpenTelemetry::SDK.configure do |config|
        config.resource = resource
        config.propagators = [ OpenTelemetry::Trace::Propagation::TraceContext.text_map_propagator ]
        config.add_span_processor(Processor.new(exporter))
        config.use("OpenTelemetry::Instrumentation::ActiveJob", span_naming: :job_class, propagation_style: :child)
      end
      provider = OpenTelemetry.tracer_provider
      self.tracer = provider.tracer("glutton.business")
      at_exit { provider.shutdown(timeout: 5) }
    end

    def trace(name, attributes: {}, parent: traceparent, links: [], kind: :internal)
      return yield unless tracer

      context = context_for(parent)
      span = tracer.start_span(name, with_parent: context, attributes:, links:, kind:)
      begin
        OpenTelemetry::Trace.with_span(span) { yield }
      rescue StandardError => error
        span.set_attribute("error.type", error.class.name)
        span.status = OpenTelemetry::Trace::Status.error
        raise
      ensure
        span.finish
      end
    end

    def current
      OpenTelemetry::Trace.current_span if tracer
    end

    def traceparent
      context = current&.context
      "00-#{context.hex_trace_id}-#{context.hex_span_id}-01" if context&.valid?
    end

    def context_for(parent)
      OpenTelemetry::Trace::Propagation::TraceContext.text_map_propagator.extract(
        { "traceparent" => parent }, context: OpenTelemetry::Context.empty)
    end

    def link(parent)
      context = OpenTelemetry::Trace.current_span(context_for(parent)).context
      OpenTelemetry::Trace::Link.new(context) if context.valid?
    end

    def ignore_routine_activity
      current&.set_attribute("glutton.routine", true)
    end
  end
end

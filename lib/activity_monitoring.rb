# frozen_string_literal: true

require "opentelemetry/sdk"
require "opentelemetry/semconv"
require "opentelemetry/exporter/otlp"

require "opentelemetry-instrumentation-active_job"

module ActivityMonitoring
  TRACER_NAME = "glutton.business"
  ACTIVE_JOB_SCOPE = OpenTelemetry::Instrumentation::ActiveJob.name
  EXPORTED_SCOPES = [ TRACER_NAME, ACTIVE_JOB_SCOPE ].freeze
  OPERATION = "glutton.operation"
  DELIVERY_COUNT = "delivery.count"
  OVERDUE = "glutton.overdue"
  OUTCOME = "outcome"
  RATING_ID = "rating.id"
  PROFILE_REVISION_ID = "profile_revision.id"
  SCHEDULED_JOBS = {
    domain_event_sweep: "DispatchDomainEventsJob",
    worker_backlog: "ReportWorkerHealthJob",
    ratings_taste_profile_refresh: "Ratings::RefreshTasteProfilesJob"
  }.freeze
  READ_METHODS = %w[GET HEAD].freeze
  HONEYCOMB_HOSTS = { "eu" => "api.eu1.honeycomb.io", "us" => "api.honeycomb.io" }.freeze

  class Exporter < OpenTelemetry::Exporter::OTLP::Exporter
    def export(spans, timeout: nil)
      # Active Job records raw exception messages and stack traces in span events.
      safe_spans = spans.map do |original|
        span = original.dup
        exception_type = Array(original.events).filter_map { |event| event.attributes&.fetch(OpenTelemetry::SemConv::EXCEPTION::EXCEPTION_TYPE, nil) }.first
        if exception_type
          span.attributes = (original.attributes || {}).merge(OpenTelemetry::SemConv::ERROR::ERROR_TYPE => exception_type)
          span.total_recorded_attributes += 1 unless original.attributes&.key?(OpenTelemetry::SemConv::ERROR::ERROR_TYPE)
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
      return unless EXPORTED_SCOPES.include?(span.instrumentation_scope.name)
      return super if span.status.code == OpenTelemetry::Trace::Status::ERROR

      attributes = span.attributes || {}
      if span.kind == :server && READ_METHODS.include?(attributes[OpenTelemetry::SemConv::HTTP::HTTP_REQUEST_METHOD])
        status = attributes[OpenTelemetry::SemConv::HTTP::HTTP_RESPONSE_STATUS_CODE]
        return if status && status < Rack::Utils.status_code(:bad_request) && !attributes.key?(OPERATION)
      end
      job_name = attributes[OpenTelemetry::SemConv::Incubating::CODE::CODE_NAMESPACE]
      if span.instrumentation_scope.name == ACTIVE_JOB_SCOPE && SCHEDULED_JOBS.value?(job_name)
        return unless span.kind == :consumer && (attributes.key?(DELIVERY_COUNT) || attributes[OVERDUE])
      end

      super
    end
  end

  class << self
    attr_accessor :tracer

    def configure
      key = ENV["HONEYCOMB_API_KEY"]
      return if key.blank?

      host = HONEYCOMB_HOSTS.fetch(ENV.fetch("HONEYCOMB_REGION"))
      exporter = Exporter.new(endpoint: "https://#{host}/v1/traces",
        headers: { "x-honeycomb-team" => key }, compression: "gzip")
      environment = ENV.fetch("HONEYCOMB_ENVIRONMENT")
      resource = OpenTelemetry::SDK::Resources::Resource.create(
        OpenTelemetry::SemConv::SERVICE::SERVICE_NAME => "glutton-#{environment}",
        OpenTelemetry::SemConv::DEPLOYMENT::DEPLOYMENT_ENVIRONMENT_NAME => environment,
        OpenTelemetry::SemConv::SERVICE::SERVICE_VERSION => ENV.fetch("RENDER_GIT_COMMIT", "local")
      )
      OpenTelemetry::SDK.configure do |config|
        config.resource = resource
        config.propagators = [ OpenTelemetry::Trace::Propagation::TraceContext.text_map_propagator ]
        config.add_span_processor(Processor.new(exporter))
        config.use(ACTIVE_JOB_SCOPE, span_naming: :job_class, propagation_style: :child)
      end
      provider = OpenTelemetry.tracer_provider
      self.tracer = provider.tracer(TRACER_NAME)
      at_exit { provider.shutdown(timeout: 5) }
    end

    def trace(name, attributes: {}, parent: traceparent, links: [], kind: :internal)
      return yield unless tracer

      context = context_for(parent)
      span = tracer.start_span(name, with_parent: context, attributes:, links:, kind:)
      begin
        OpenTelemetry::Trace.with_span(span) { yield }
      rescue StandardError => error
        span.set_attribute(OpenTelemetry::SemConv::ERROR::ERROR_TYPE, error.class.name)
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
  end
end

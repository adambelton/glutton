require "opentelemetry/sdk"
require "opentelemetry/semconv"
require "opentelemetry/exporter/otlp"

require "opentelemetry-instrumentation-active_job"

require_relative "activity_monitoring/span_session"
require_relative "activity_monitoring/model_span"
require_relative "activity_monitoring/business_span"

module ActivityMonitoring
  BUSINESS_OPERATION = "business_operation.glutton".freeze

  MODEL_TAGS = OpenTelemetry::Context.create_key("glutton.model.tags")
  BUSINESS_CONTEXT = OpenTelemetry::Context.create_key("glutton.business.context")
  private_constant :MODEL_TAGS, :BUSINESS_CONTEXT

  module Scopes
    BUSINESS = "glutton.business".freeze
    RATINGS = "glutton.ratings".freeze
    REGISTRY = "glutton.registry".freeze
    CONNECTION_CHECK = "glutton.ai.connection-check".freeze
    ACTIVE_JOB = OpenTelemetry::Instrumentation::ActiveJob.name

    ALL = [ BUSINESS, ACTIVE_JOB ].freeze
  end

  module Attributes
    DOMAIN = "glutton.domain".freeze
    FILM_ID = "film.id".freeze
    OPERATION = "glutton.operation".freeze
    OUTCOME = "outcome".freeze
    REQUEST_ID = "request.id".freeze
    USER_ID = "user.id".freeze
    RATING_ID = "rating.id".freeze
    PROFILE_REVISION_ID = "profile_revision.id".freeze
    PROFILE_REFRESH_REQUESTED = "profile_refresh.requested".freeze
    EVENT_ID = "event.id".freeze
    CORRELATION_ID = "correlation.id".freeze
    SUBSCRIBER = "subscriber".freeze
    DELIVERY_ID = "delivery.id".freeze
    DELIVERY_COUNT = "delivery.count".freeze
    DELIVERY_AGE_MS = "delivery.age_ms".freeze
    ATTEMPT = "attempt".freeze
    OVERDUE = "glutton.overdue".freeze
  end

  module Operations
    SEARCH_FILMS = "search films".freeze
    RANK_RECOMMENDATION_FILMS = "rank recommendation films".freeze
    CREATE_RATING_FILM = "create rating film".freeze
  end

  module AssessmentOutcomes
    ALREADY_ASSESSED = "already_assessed".freeze
    NO_QUALITIES = "no_qualities".freeze
    ASSESSED = "assessed".freeze
    SUPERSEDED = "superseded".freeze
    REMOVED = "removed".freeze
  end

  module ScheduledJobs
    DOMAIN_EVENT_SWEEP = "DispatchDomainEventsJob".freeze
    WORKER_BACKLOG = "ReportWorkerHealthJob".freeze
    RATINGS_TASTE_PROFILE_REFRESH = "Ratings::RefreshTasteProfilesJob".freeze

    ALL = [ DOMAIN_EVENT_SWEEP, WORKER_BACKLOG, RATINGS_TASTE_PROFILE_REFRESH ].freeze
  end

  HONEYCOMB_HOSTS = { "eu" => "api.eu1.honeycomb.io".freeze, "us" => "api.honeycomb.io".freeze }.freeze

  class BusinessOperationSubscriber
    def start(_name, _id, payload)
      payload[:monitoring_session] = ActivityMonitoring.start_business_operation(payload.fetch(:operation), domain: payload.fetch(:domain))
    end

    def finish(_name, _id, payload)
      payload[:monitoring_session]&.finish(error: payload[:exception_object])
    end
  end

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
    READ_METHODS = [ "GET".freeze, "HEAD".freeze ].freeze

    def on_finish(span)
      return unless Scopes::ALL.include?(span.instrumentation_scope.name)
      return super if span.status.code == OpenTelemetry::Trace::Status::ERROR

      attributes = span.attributes || {}
      if span.kind == :server && READ_METHODS.include?(attributes[OpenTelemetry::SemConv::HTTP::HTTP_REQUEST_METHOD])
        status = attributes[OpenTelemetry::SemConv::HTTP::HTTP_RESPONSE_STATUS_CODE]
        return if status && status < Rack::Utils.status_code(:bad_request) && !attributes.key?(Attributes::OPERATION)
      end
      job_name = attributes[OpenTelemetry::SemConv::Incubating::CODE::CODE_NAMESPACE]
      if span.instrumentation_scope.name == Scopes::ACTIVE_JOB && ScheduledJobs::ALL.include?(job_name)
        return unless span.kind == :consumer && (attributes.key?(Attributes::DELIVERY_COUNT) || attributes[Attributes::OVERDUE])
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
        config.use(Scopes::ACTIVE_JOB, span_naming: :job_class, propagation_style: :child)
      end
      provider = OpenTelemetry.tracer_provider
      self.tracer = provider.tracer(Scopes::BUSINESS)
      at_exit { provider.shutdown(timeout: 5) }
    end

    def start_business_operation(name, domain:)
      return unless tracer

      SpanSession.new(tracer, name, span_class: BusinessSpan, parent: business_context, attributes: { Attributes::DOMAIN => domain })
    end

    def trace_business_operation(name, attributes: {}, parent: traceparent, links: [], kind: :internal)
      return yield unless tracer

      session = SpanSession.new(tracer, name, span_class: BusinessSpan, parent: context_for(parent), attributes:, links:, kind:)
      session.record { |span| yield span }
    end

    def trace_model(name, scope:, tags:, input:, provider: model_provider, environment: Rails.application.config.x.langfuse_environment, version: nil)
      tracer = model_tracer(scope, provider:)
      context = OpenTelemetry::Context.empty.set_value(BUSINESS_CONTEXT, business_context).set_value(MODEL_TAGS, tags)
      OpenTelemetry::Context.with_current(context) do
        ModelSpan.record(tracer, name, type: "span", trace_name: name, tags:, input:, environment:, version:) do |span|
          yield span, tracer
        end
      end
    ensure
      provider&.force_flush(timeout: 5)
    end

    def trace_generation(name, tracer:, tags: OpenTelemetry::Context.value(MODEL_TAGS), input: nil, environment: Rails.application.config.x.langfuse_environment,
      model: nil, parameters: nil, trace_name: nil, version: nil, &block)
      ModelSpan.record(tracer, name, type: "generation", tags:, input:, environment:, model:, parameters:, trace_name:, version:, &block)
    end

    def model_provider
      Rails.application.config.x.langfuse_tracer_provider
    end

    def model_tracer(scope, provider:)
      (provider || OpenTelemetry::Trace::TracerProvider.new).tracer(scope, "1")
    end

    def within_business_context(&block)
      OpenTelemetry::Context.with_current(business_context, &block)
    end

    def business_context
      OpenTelemetry::Context.value(BUSINESS_CONTEXT) || OpenTelemetry::Context.current
    end
    private :business_context

    def current
      BusinessSpan.new(OpenTelemetry::Trace.current_span(business_context)) if tracer
    end

    def traceparent
      return unless tracer

      context = OpenTelemetry::Trace.current_span(business_context).context
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

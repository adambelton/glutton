module ActivityMonitoring
  class AiSpan
    module Fields
      TRACE_NAME = "langfuse.trace.name".freeze
      ENVIRONMENT = "langfuse.environment".freeze
      TAGS = "langfuse.trace.tags".freeze
      VERSION = "langfuse.version".freeze
      TYPE = "langfuse.observation.type".freeze
      INPUT = "langfuse.observation.input".freeze
      OUTPUT = "langfuse.observation.output".freeze
      MODEL = "langfuse.observation.model.name".freeze
      PARAMETERS = "langfuse.observation.model.parameters".freeze
      USAGE = "langfuse.observation.usage_details".freeze
      COST = "langfuse.observation.cost_details".freeze
      LEVEL = "langfuse.observation.level".freeze
    end

    def self.record(tracer, name, type:, tags:, input:, environment:, trace_name: nil, version: nil, model: nil, parameters: nil, &block)
      attributes = {
        Fields::TYPE => type, Fields::ENVIRONMENT => environment, Fields::TAGS => tags,
        Fields::TRACE_NAME => trace_name, Fields::VERSION => version, Fields::MODEL => model,
        Fields::INPUT => input&.to_json, Fields::PARAMETERS => parameters&.to_json
      }.compact
      session = SpanSession.new(tracer, name, span_class: self, parent: OpenTelemetry::Context.current, attributes:)
      session.record(&block)
    end

    def initialize(span)
      @span = span
    end

    def record_failure(error)
      @span.set_attribute(Fields::LEVEL, "ERROR")
      @span.status = OpenTelemetry::Trace::Status.error(error.class.name)
    end

    def trace_id
      @span.context.hex_trace_id if @span.context.valid?
    end

    def set_model(model)
      @span.set_attribute(Fields::MODEL, model)
    end

    def set_output(output)
      @span.set_attribute(Fields::OUTPUT, output.to_json)
    end

    def set_usage(usage)
      @span.set_attribute(Fields::USAGE, usage.to_json)
    end

    def set_cost(cost)
      @span.set_attribute(Fields::COST, cost.to_json)
    end

    def set_response(id:, status:)
      @span.set_attribute("langfuse.observation.metadata.response_id", id)
      @span.set_attribute("langfuse.observation.metadata.response_status", status.to_s)
    end

    def set_attribute(key, value)
      @span.set_attribute(key, value)
    end
  end
end

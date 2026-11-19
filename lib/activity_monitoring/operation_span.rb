module ActivityMonitoring
  class OperationSpan
    def initialize(span)
      @span = span
    end

    def record_failure(error)
      @span.set_attribute(OpenTelemetry::SemConv::ERROR::ERROR_TYPE, error.class.name)
      @span.status = OpenTelemetry::Trace::Status.error
    end

    def set_operation(operation)
      @span.set_attribute(Attributes::OPERATION, operation)
    end

    def set_outcome(outcome)
      @span.set_attribute(Attributes::OUTCOME, outcome)
    end

    def set_rating_id(id)
      @span.set_attribute(Attributes::RATING_ID, id)
    end

    def set_film_id(id)
      @span.set_attribute(Attributes::FILM_ID, id)
    end

    def set_profile_revision_id(id)
      @span.set_attribute(Attributes::PROFILE_REVISION_ID, id)
    end

    def profile_refresh_requested
      @span.set_attribute(Attributes::PROFILE_REFRESH_REQUESTED, true)
    end

    def set_delivery_count(count)
      @span.set_attribute(Attributes::DELIVERY_COUNT, count)
    end

    def set_delivery_result(outcome:, attempt:, age_ms:, error_type:)
      set_outcome(outcome.to_s)
      @span.set_attribute(Attributes::ATTEMPT, attempt)
      @span.set_attribute(Attributes::DELIVERY_AGE_MS, age_ms)
      @span.set_attribute(OpenTelemetry::SemConv::ERROR::ERROR_TYPE, error_type) if error_type.present?
      @span.status = OpenTelemetry::Trace::Status.error if outcome == :failed
    end

    def set_overdue_wait(kind, seconds)
      @span.set_attribute(Attributes::OVERDUE, true)
      @span.set_attribute("wait.#{kind}.seconds", seconds)
    end

    def set_http_response(response)
      @span.set_attribute(OpenTelemetry::SemConv::HTTP::HTTP_RESPONSE_STATUS_CODE, response.status)
      @span.status = OpenTelemetry::Trace::Status.error if response.server_error?
    end
  end
end

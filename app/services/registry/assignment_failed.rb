module Registry
  class AssignmentFailed < StandardError
    attr_reader :reason, :provider_response, :request_sent

    def initialize(reason:, provider_response: nil, request_sent: nil)
      @reason, @provider_response, @request_sent = reason, provider_response, request_sent
      super(I18n.t("registry.assignment.errors.#{reason}"))
    end
  end
end

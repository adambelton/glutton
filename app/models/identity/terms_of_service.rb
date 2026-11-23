module Identity
  class TermsOfService
    VERSIONS = %w[1].freeze
    CURRENT_VERSION = VERSIONS.last

    attr_reader :version

    def initialize(version:)
      @version = version
    end

    def self.current
      new(version: CURRENT_VERSION)
    end

    def translation_scope
      "identity.terms_of_service_v#{version}"
    end
  end
end

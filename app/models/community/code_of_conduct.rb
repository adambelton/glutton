module Community
  class CodeOfConduct
    VERSIONS = %w[1].freeze
    CURRENT_VERSION = VERSIONS.last

    attr_reader :version

    def initialize(version:)
      @version = version
    end

    def self.current
      new(version: CURRENT_VERSION)
    end

    def accepted_by?(user:)
      user.accepted_community_code_of_conduct?(version:)
    end

    def version_for_acceptance!(displayed_version:, accepted:)
      raise Errors::CodeOfConductChanged unless displayed_version == version
      raise Errors::ExplicitAcceptanceRequired unless accepted

      version
    end

    def translation_scope
      "community.code_of_conduct_v#{version}"
    end
  end
end

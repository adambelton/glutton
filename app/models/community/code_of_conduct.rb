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

    def accepted_by?(member:)
      member.accepted_community_code_of_conduct?(version:)
    end

    def translation_scope
      "community.code_of_conduct_v#{version}"
    end
  end
end

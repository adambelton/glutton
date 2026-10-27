module FilmKnowledge
  class GenerationFailed < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super("Film analysis generation failed: #{reason}")
    end
  end
end

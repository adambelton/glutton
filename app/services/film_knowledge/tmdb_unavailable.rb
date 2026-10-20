module FilmKnowledge
  class TmdbUnavailable < StandardError
    attr_reader :reason

    def initialize(reason:)
      @reason = reason
      super("TMDB request failed (#{reason})")
    end
  end
end

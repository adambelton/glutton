module Ratings
  class RatingQualityAssessment
    attr_reader :result

    def initialize(expressions:, qualities:, profile_revision_id:, profile:, trace_id:)
      @qualities = qualities
      @profile_revision_id = profile_revision_id
      @profile = profile
      @explicit = ExplicitQualityAssessment.new(expressions:, qualities:, trace_id:)
    end

    def call(client:)
      @result = @explicit.call(client:).result
      return self if @profile_revision_id.nil?

      explicit_ids = @result.fetch("decisions").select { |decision| decision.fetch("applicable") }.pluck("quality_id")
      eligible_qualities = @qualities.except(*explicit_ids.map(&:to_s))
      @result = @result.merge("implicit_assessment" =>
        ImplicitQualityAssessment.new(profile_revision_id: @profile_revision_id, profile: @profile, qualities: eligible_qualities).call(client:))
      self
    end
  end
end

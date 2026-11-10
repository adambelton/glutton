module Ratings
  module QualityScoring
    class EvaluateRatingQualities
      attr_reader :input, :result

      def initialize(notes:, qualities:, profile_revision_id:, profile:, trace_id:, explicit_evidence: nil, previous_assessment: nil)
        @qualities = qualities
        @profile_revision_id = profile_revision_id
        @profile = profile
        @notes = notes
        @trace_id = trace_id
        @explicit_evidence = explicit_evidence
        @previous_result = previous_assessment&.result
        @input = previous_assessment&.input&.dup || []
        @responses = @previous_result&.fetch("provider_responses")&.dup || []
      end

      def call(client:)
        @result = if @explicit_evidence.present?
          @explicit_evidence.merge("trace_id" => @trace_id)
        else
          explicit = EvaluateExplicitQualities.new(notes: @notes, qualities: @qualities, trace_id: @trace_id).call(client:)
          capture_calls(explicit)
          explicit.result
        end
        @result = @result.merge("provider_responses" => @responses)
        return self if @profile_revision_id.nil?

        eligible = eligible_qualities(@result)
        implicit = if @previous_result.present? && eligible == eligible_qualities(@previous_result)
          @previous_result.fetch("implicit_assessment")
        else
          assessment = EvaluateImplicitQualities.new(profile_revision_id: @profile_revision_id, profile: @profile, qualities: eligible).call(client:)
          capture_calls(assessment)
          assessment.result
        end
        @result = @result.merge("implicit_assessment" => implicit)
        self
      end

      private

      def capture_calls(assessment)
        assessment.provider_calls.each do |call|
          @input << call.slice("phase", "request")
          @responses << call.slice("phase", "response")
        end
      end

      def eligible_qualities(result)
        explicit_ids = result.fetch("decisions").select { |decision| decision.fetch("applicable") }.pluck("quality_id")
        result.fetch("qualities").except(*explicit_ids.map(&:to_s))
      end
    end
  end
end

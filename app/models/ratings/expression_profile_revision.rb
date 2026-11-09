module Ratings
  class ExpressionProfileRevision < ApplicationRecord
    belongs_to :expression_profile
    belongs_to :expression_profile_revision_eval

    def legacy_annotations?
      profile.present? && !annotations.any? { |annotation| annotation.key?("end_offset") }
    end

    def incremental_synthesis_basis
      return if profile.blank? || legacy_annotations?

      output = expression_profile_revision_eval.output
      { revision_id: id, profile:, evidence: output.fetch("evidence"), annotations: }
    end

    def readonly?
      super || persisted?
    end
  end
end

module Ratings
  class ExpressionProfileRevision < ApplicationRecord
    belongs_to :expression_profile
    belongs_to :expression_profile_eval

    def legacy_annotations?
      profile.present? && !expression_profile_eval.output.fetch("annotations", []).any? { |annotation| annotation.key?("end_offset") }
    end

    def readonly?
      super || persisted?
    end
  end
end

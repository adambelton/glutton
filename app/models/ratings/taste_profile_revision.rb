module Ratings
  class TasteProfileRevision < ApplicationRecord
    belongs_to :taste_profile
    belongs_to :taste_profile_revision_eval

    def incremental_synthesis_basis
      return if profile.blank?

      output = taste_profile_revision_eval.output
      { revision_id: id, profile:, evidence: output.fetch("evidence"), annotations: }
    end

    def readonly?
      super || persisted?
    end
  end
end

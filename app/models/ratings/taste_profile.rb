module Ratings
  class TasteProfile < ApplicationRecord
    belongs_to :user, class_name: "Identity::User"
    has_many :revisions, class_name: "TasteProfileRevision"

    def current_revision
      revisions.order(id: :desc).first
    end

    def publish_revision!(evaluation:)
      unless evaluation.persisted? && evaluation.taste_profile == self
        raise Errors::TasteProfileRefreshFailed.new(reason: :unrecorded_evaluation)
      end

      with_lock(requires_new: true) do
        if revisions.exists?(taste_profile_revision_eval: evaluation)
          raise Errors::TasteProfileRefreshFailed.new(reason: :already_applied)
        end

        attributes = evaluation.revision_attributes
        if attributes.fetch(:notes).empty? && !revisions.exists?
          raise Errors::TasteProfileRefreshFailed.new(reason: :missing_initial_evidence)
        end

        revisions.create!(taste_profile_revision_eval: evaluation, **attributes)
      end
    end
  end
end

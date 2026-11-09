module Ratings
  class ExpressionProfile < ApplicationRecord
    belongs_to :user, class_name: "Identity::User"
    has_many :revisions, class_name: "ExpressionProfileRevision"

    def current_revision
      revisions.order(id: :desc).first
    end

    def publish_revision!(evaluation:)
      unless evaluation.persisted? && evaluation.expression_profile == self
        raise ExpressionProfileRefreshFailed.new(reason: :unrecorded_evaluation)
      end

      with_lock(requires_new: true) do
        if revisions.exists?(expression_profile_revision_eval: evaluation)
          raise ExpressionProfileRefreshFailed.new(reason: :already_applied)
        end

        attributes = evaluation.revision_attributes
        if attributes.fetch(:expression_texts).empty? && !revisions.exists?
          raise ExpressionProfileRefreshFailed.new(reason: :missing_initial_evidence)
        end

        revisions.create!(expression_profile_revision_eval: evaluation, **attributes)
      end
    end
  end
end

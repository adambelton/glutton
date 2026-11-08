module Ratings
  class ExpressionProfile < ApplicationRecord
    belongs_to :user, class_name: "Identity::User"
    has_many :revisions, class_name: "ExpressionProfileRevision"

    def current_revision
      revisions.order(id: :desc).first
    end

    def publish_revision!(expression_profile_eval:, profile:, expression_texts:)
      if expression_texts.empty? && !revisions.exists?
        raise ExpressionProfileRefreshFailed.new(reason: :missing_initial_evidence)
      end

      revisions.create!(expression_profile_eval:, profile:, expression_texts:)
    end
  end
end

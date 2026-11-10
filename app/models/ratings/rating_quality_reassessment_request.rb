module Ratings
  class RatingQualityReassessmentRequest < ApplicationRecord
    belongs_to :user, class_name: "Identity::User"
    belongs_to :taste_profile_revision

    def self.mark_pending!(user:, revision:)
      upsert({ user_id: user.id, taste_profile_revision_id: revision.id }, unique_by: :user_id)
    end

    def pending?
      pending_revision.exists?
    end

    def acknowledge!
      pending_revision.delete_all
    end

    private

    def pending_revision
      self.class.where(id:, taste_profile_revision_id:)
    end
  end
end

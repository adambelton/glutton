module Ratings
  class ExpressionProfileRefreshRequest < ApplicationRecord
    belongs_to :user, class_name: "Identity::User"

    def self.mark_pending!(user_id:)
      upsert({ user_id:, generation: SecureRandom.uuid }, unique_by: :user_id)
    end

    def acknowledge!
      self.class.where(id:, generation:).delete_all
    end
  end
end

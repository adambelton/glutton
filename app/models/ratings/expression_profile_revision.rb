module Ratings
  class ExpressionProfileRevision < ApplicationRecord
    belongs_to :expression_profile
    belongs_to :expression_profile_eval

    def readonly?
      super || persisted?
    end
  end
end

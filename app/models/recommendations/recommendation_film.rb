module Recommendations
  class RecommendationFilm < ApplicationRecord
    belongs_to :user, class_name: "Identity::User"
    belongs_to :film, class_name: "Registry::Film"

    module Responses
      ACCEPTED = "accepted".freeze
      REJECTED = "rejected".freeze
      ALL = [ ACCEPTED, REJECTED ].freeze
    end

    scope :eligible, -> { where(response: nil, suppressed: false) }

    validates :suppressed, inclusion: { in: [ true, false ] }
    validates :response, inclusion: { in: Responses::ALL }, allow_nil: true
    validates :film_id, uniqueness: { scope: :user_id }

    def suppress!
      return :ignored if suppressed?

      update!(suppressed: true)
      :processed
    end

    def discard_suppression_only_record!
      return :ignored unless suppressed? && recommended_at.nil? && response.nil?

      destroy!
      :processed
    end

    def record_response!(response:)
      raise Errors::ResponseUnavailable unless self.response.nil?

      update!(response:)
      self
    end
  end
end

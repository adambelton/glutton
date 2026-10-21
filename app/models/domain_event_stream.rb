class DomainEventStream < ApplicationRecord
  module PublishingDomains
    LIBRARY = "library".freeze
    RATINGS = "ratings".freeze
    RECOMMENDATIONS = "recommendations".freeze
    ALL = [ LIBRARY, RATINGS, RECOMMENDATIONS ].freeze
  end

  belongs_to :user
  has_many :domain_events

  validates :publisher, inclusion: { in: PublishingDomains::ALL }

  def append!(**attributes)
    increment!(:sequence)
    domain_events.create!(**attributes, sequence:)
  end
end

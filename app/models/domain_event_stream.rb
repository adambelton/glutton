class DomainEventStream < ApplicationRecord
  belongs_to :user
  has_many :domain_events

  validates :publisher, presence: true

  def append!(**attributes)
    increment!(:sequence)
    domain_events.create!(**attributes, sequence:)
  end
end

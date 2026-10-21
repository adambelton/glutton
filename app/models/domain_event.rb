class DomainEvent < ApplicationRecord
  belongs_to :domain_event_stream

  def readonly?
    persisted?
  end
end

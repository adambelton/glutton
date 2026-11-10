module DomainEvents
  module Delivery
    Subscription = Data.define(:name, :publisher, :event_names, :handler)
  end
end

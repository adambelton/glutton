module DomainEvents
  Subscription = Data.define(:name, :publisher, :event_names, :handler)
end

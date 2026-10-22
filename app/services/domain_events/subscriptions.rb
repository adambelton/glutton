module DomainEvents
  module Subscriptions
    def self.all
      [ Subscription.new(name: Library::ConsumeRatingsEvent::SUBSCRIBER, publisher: Ratings::EVENTS_PUBLISHING_DOMAIN,
        event_names: Library::ConsumeRatingsEvent::EVENT_NAMES, handler: Library::ConsumeRatingsEvent),
        Subscription.new(name: Ratings::ConsumeLibraryEvent::SUBSCRIBER, publisher: Library::EVENTS_PUBLISHING_DOMAIN,
          event_names: Ratings::ConsumeLibraryEvent::EVENT_NAMES, handler: Ratings::ConsumeLibraryEvent) ]
    end
  end
end

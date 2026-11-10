module DomainEvents
  module Delivery
    module Subscriptions
      def self.all
        [ Subscription.new(name: Library::EventHandlers::ConsumeRatingsEvent::SUBSCRIBER, publisher: Ratings::Events::PUBLISHING_DOMAIN,
          event_names: Library::EventHandlers::ConsumeRatingsEvent::EVENT_NAMES, handler: Library::EventHandlers::ConsumeRatingsEvent),
          Subscription.new(name: Ratings::EventHandlers::ConsumeLibraryEvent::SUBSCRIBER, publisher: Library::Events::PUBLISHING_DOMAIN,
            event_names: Ratings::EventHandlers::ConsumeLibraryEvent::EVENT_NAMES, handler: Ratings::EventHandlers::ConsumeLibraryEvent) ]
      end
    end
  end
end

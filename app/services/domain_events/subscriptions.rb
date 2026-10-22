module DomainEvents
  module Subscriptions
    def self.all
      [ Subscription.new(name: Library::ConsumeRating::SUBSCRIBER, publisher: Ratings::EVENTS_PUBLISHING_DOMAIN,
        event_names: [ Ratings::Events::RATING_SUBMITTED ], handler: Library::ConsumeRating) ]
    end
  end
end

module DomainEvents
  module Delivery
    module Subscriptions
      def self.all
        [ build(publisher: Ratings::Events::PUBLISHING_DOMAIN, handler: Library::EventHandlers::ConsumeRatingsEvent),
          build(publisher: Recommendations::Events::PUBLISHING_DOMAIN, handler: Library::EventHandlers::ConsumeRecommendationsEvent),
          build(publisher: Library::Events::PUBLISHING_DOMAIN, handler: Ratings::EventHandlers::ConsumeLibraryEvent),
          build(publisher: Library::Events::PUBLISHING_DOMAIN, handler: Recommendations::EventHandlers::ConsumeLibraryEvent),
          build(publisher: Ratings::Events::PUBLISHING_DOMAIN, handler: Recommendations::EventHandlers::ConsumeRatingsEvent) ]
      end

      def self.build(publisher:, handler:)
        Subscription.new(name: handler::SUBSCRIBER, publisher:, event_names: handler::EVENT_NAMES, handler:)
      end
      private_class_method :build
    end
  end
end

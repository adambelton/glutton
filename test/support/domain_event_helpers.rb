class EventEffect < ApplicationRecord
end

module DomainEventHelpers
  def prepare_events
    freeze_time
    @user = UserGuest.create!
    EventEffect.connection.create_table(:event_effects) do |t|
      t.uuid :event_id, null: false
      t.string :subscriber, null: false
      t.integer :value, null: false
    end
  end

  def publish(stream_key: "film:1", user_id: @user.id, **attributes)
    User.transaction do
      DomainEvents::Publish.call(user_id:, publisher: DomainEvents::PublishingDomains::LIBRARY, stream_key:,
        name: "Changed", payload: { value: 1 }, **attributes)
    end
  end

  def subscription(name: "projection", &handler)
    handler ||= ->(event:, user:) do
      EventEffect.create!(event_id: event.id, subscriber: name, value: event.payload.fetch("value"))
      :processed
    end
    DomainEvents::Subscription.new(name:, publisher: DomainEvents::PublishingDomains::LIBRARY, event_names: [ "Changed" ], handler:)
  end

  def dispatch(*subscriptions, limit: 100)
    DomainEvents::Dispatch.call(subscriptions:, limit:)
  end

  def delivery(event, subscriber: "projection")
    EventDelivery.find_by!(domain_event: event, subscriber:)
  end
end

class RemoveDomainEventPublisherAllowlist < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :domain_event_streams,
      "publisher IN ('library', 'ratings', 'recommendations')",
      name: "domain_event_stream_publisher"
  end
end

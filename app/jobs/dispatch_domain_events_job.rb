class DispatchDomainEventsJob < ApplicationJob
  queue_as :domain_events

  def perform
    counts = DomainEvents::Delivery::Drain.call
    ActivityMonitoring.current&.set_attribute(ActivityMonitoring::DELIVERY_COUNT, counts.values.sum) if counts.present?
    counts
  rescue StandardError => error
    # Database exceptions may contain private row values; retain the class only.
    raise DomainEvents::Errors::DispatchFailure, "Event dispatch failed (#{error.class.name})", cause: nil
  end
end

class DispatchDomainEventsJob < ApplicationJob
  queue_as :domain_events

  def perform
    DomainEvents::Delivery::Drain.call
  rescue StandardError => error
    # Database exceptions may contain private row values; retain the class only.
    raise DomainEvents::Errors::DispatchFailure, "Event dispatch failed (#{error.class.name})", cause: nil
  end
end

class DispatchDomainEventsJob < ApplicationJob
  queue_as :domain_events

  def perform
    counts = DomainEvents::Delivery::Drain.call
    Appsignal.set_namespace("idle_domain_events") if counts.empty? && defined?(Appsignal)
    counts
  rescue StandardError => error
    # Database exceptions may contain private row values; retain the class only.
    raise DomainEvents::Errors::DispatchFailure, "Event dispatch failed (#{error.class.name})", cause: nil
  end
end

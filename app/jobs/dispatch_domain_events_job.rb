class DispatchDomainEventsJob < ApplicationJob
  queue_as :domain_events

  def perform
    counts = DomainEvents::Dispatch.call
    # Drain ordered successors promptly; delayed retries are recovered by the sweep.
    DomainEvents::Wake.call if counts.values_at(:processed, :ignored, :skipped).compact.sum.positive?
    counts
  rescue StandardError => error
    # Database exceptions may contain private row values; retain the class only.
    raise DomainEvents::DispatchFailure, "Event dispatch failed (#{error.class.name})", cause: nil
  end
end

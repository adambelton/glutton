namespace :domain_events do
  desc "Report domain-event backlog counts and failures without payloads"
  task status: :environment do
    puts JSON.generate(DomainEvents::Status.call)
  end

  desc "Poll one bounded batch of domain events"
  task dispatch: :environment do
    puts JSON.generate(DomainEvents::Dispatch.call)
  rescue StandardError => error
    warn "Event dispatch failed (#{error.class.name}); polling can be retried."
    exit 1
  end

  desc "Retry a failed delivery by ID (completed deliveries cannot be reset)"
  task :retry, [ :delivery_id ] => :environment do |_task, args|
    delivery = EventDelivery.find(args.fetch(:delivery_id))
    delivery.with_lock { delivery.retry! }
    puts "Delivery #{delivery.id} is pending."
  end
end

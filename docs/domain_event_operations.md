# Domain-event operations

Task 001i uses GoodJob 4.22 with PostgreSQL notifications, external workers and a 30-second recovery sweep. Active Job carries only a dispatcher job, with no event payload or user ID. Source changes and events commit together; dispatch is enqueued after commit. Notifications reduce latency; the retained outbox recovers an unsuccessful enqueue. Subscriber effects and receipts commit in one transaction.

## Worker configuration

Run `RAILS_ENV=production bin/jobs` with `JOB_DATABASE_URL` supplied securely through the process environment. It must point directly to the **same database** used by the web process. Do not use a transaction-mode PgBouncer endpoint: notifications and advisory locks require session connections. The worker sets its entire Active Record connection to this endpoint so handlers and receipts share transactions. Web processes can retain their own connection configuration.

The default worker has two execution threads and a five-connection Rails pool. Budget five connections per worker process, plus web connections and operational headroom. If increasing worker threads, increase its `RAILS_MAX_THREADS` connection limit accordingly; allow the execution threads plus three utility/headroom connections. This setting changes the pool for that process only. Start with one worker and measure backlog age, job duration, database load and connection use before scaling.

Development also uses external execution: run `bin/jobs` alongside the web server when exercising asynchronous features. Tests normally use the test adapter; backend integration tests explicitly use GoodJob against the test database. Cron is disabled in tests. No worker or scheduler has been deployed by this task.

## Inspection and recovery

- `bin/rails domain_events:status` reports retained events, undiscovered events per registered subscriber, delivery counts, oldest outstanding age and up to 100 failed receipt IDs/subscriber names/error classes. It excludes payload and exception messages. An empty registry has no subscriber backlog; events remain retained.
- `bin/rails domain_events:dispatch` processes one bounded batch per subscriber. The worker normally runs this through `DispatchDomainEventsJob`, including recurring recovery and immediate follow-up after progress.
- `bin/rails 'domain_events:retry[123]'` resets failed receipt 123 after its underlying problem is fixed. The next sweep processes it. Pending or completed receipts cannot be reset through this operation.

Ordinary handler failures roll back their writes and retry with exponential delays from five seconds to five minutes. After ten attempts the receipt remains failed and blocks later accepted events in that subscriber's stream; other streams/subscribers continue. Hard process termination rolls back in-flight effects and receipts; GoodJob can retry the interrupted dispatcher. A later sweep can also rediscover pending work. No network side effects belong inside handlers.

Backend-level failures are distinct from failed subscriber receipts. Monitor worker health and GoodJob unfinished/discarded jobs alongside outbox age. The next sweep recovers an unsuccessful dispatcher execution; inspect persistent failures rather than repeatedly resetting receipts. GoodJob's dashboard is not mounted: adding authenticated operational access is separate work.

## Retention and boundaries

GoodJob retains finished execution records for seven days before normal worker cleanup. Domain events and receipts have no age-based purge yet, enabling later subscribers to bootstrap. Physical user cleanup cascades through streams, events and receipts; guest claim keeps the same ownership. Monitor table growth. Active-owner compaction requires an explicit checkpoint/bootstrap policy before deleting history.

The production subscription registry is intentionally empty. Library publication/bootstrap and each domain's subscriptions remain separate tasks. Delivery cannot make a domain action succeed, resolve conflicting domain rules or provide a synchronous cross-domain result.

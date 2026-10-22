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

The registry includes `library.completed_ratings`, owned by Library, for Ratings `RatingSubmitted` v1 events. It creates or transitions Library entries to watched, including NotInterested; already watched is ignored without another event. Actual changes publish FilmMarkedWatched with source correlation and causation in the receipt transaction. Public duplicate-action failures are unchanged. No worker deployment is implied.

Catch-up uses retained events automatically: run `RAILS_ENV=development bin/rails domain_events:status`, then `RAILS_ENV=development bin/rails domain_events:dispatch` for bounded progress. Repeat while matching undiscovered or due work remains, or run the existing worker/recovery sweep. A batch returning no processed work is not proof of completed catch-up: discovery can find a later event before its predecessor, and retries may not yet be due. Inspect status rather than assuming one command drains the backlog. No snapshot or new source baseline is required.

Unsupported versions, malformed contract data and missing Film records fail delivery explicitly; inspect failure classes and repair the underlying problem before using the retry command above. Do not skip malformed facts automatically or consult Ratings tables as a fallback. Existing inactive-owner skips and physical cleanup apply. Other domain subscribers remain separate tasks; Library's own watched events do not cause this subscriber to run again.

## Ratings Library-event consumer

Task 017 registers `ratings.library_events` for FilmMarkedWatched, FilmMarkedNotInterested, FilmAddedToWatchlist and FilmRemovedFromWatchlist v1. Watchlist addition holds a RatingFilm; watchlist removal releases an existing hold without creating a missing row. Watched admits a missing row or releases its hold. Not-interested dismisses and releases any hold. Dismissal is never cleared; FilmDismissalRemoved is not subscribed to. All changes and the delivery receipt share one transaction; the handler emits no events.

The same status/dispatch/retry commands above catch up retained matching events. Hold/release order matters: a failing predecessor blocks subsequent matching events in its stream. Replaying a completed receipt does not reapply an older hold. Do not bypass Deliver to replay handlers. Invalid consumed identifiers/versions and missing Film records retry/fail explicitly. Existing cleanup cascades candidates and receipts; claim preserves identities. No new worker configuration or deployment is required or performed by this task.

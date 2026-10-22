# 016a — Library event-handler namespace

Status: Ready for review — implemented 22 October 2026  
Owner: Library / event consumption

## Goal

Align the existing completed-rating handler with the agreed ReceivingDomain::EventHandlers::PublishingDomain::EventName convention.

## Scope

- Owner follow-up: introduce Library::ConsumeRatingsEvent as the subscription entry point, owning the existing subscriber name, explicit handler mapping, shared validation and loading. Keep RatingSubmitted as the event-specific reaction, with unchanged atomicity and causal publication.

- Move Library::ConsumeRating to Library::EventHandlers::Ratings::RatingSubmitted and update registration/test references.
- Preserve subscriber identity, event contract, validation, transactions and outcomes. Qualify publisher constants where the nested namespace would shadow the publishing domain.
- Record the convention in repository instructions and event documentation. Subscription coordinators may retain shared loading/validation and ordered dispatch outside the reaction-handler namespace.

## Scope restrictions

- Library behaviour is unchanged. No Ratings behaviour, transport changes, subscriptions, schema changes or new abstractions.
- This is an independently verified Library naming follow-up to the owner's request for consistent handler structure; task 017 retains its Ratings ownership.

## Acceptance criteria

- **AC1:** The existing Library handler uses the agreed domain/event namespace with unchanged behaviour.
  Check: existing Library/Ratings delivery and concurrency regressions, application eager loading and a reference search for the old constant.
  Result: Passed — `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/library test/services/ratings test/services/domain_events test/jobs`: 148 tests / 1,329 assertions. `RAILS_ENV=test bin/rails zeitwerk:check` passed with the existing mailer-preview exclusion notice; no old handler constant remains in app/test.
- **AC2:** Conventions and checks are recorded.
  Check: targeted Ruby style and `git diff --check`; document exact verification results.
  Result: Passed — targeted RuboCop on the moved handler, registry and both changed Library tests: 4 files, no offenses. `git diff --check` passed. Convention recorded in AGENTS.md and docs/domain_events.md.

## Implementation notes

Moved the existing handler to Library::EventHandlers::Ratings::RatingSubmitted, updated references and qualified ::Ratings publisher constants to avoid lexical shadowing. Existing subscriber name and behaviour are unchanged. No deployment or migrations.

Owner acceptance / merge: Pending.

Owner entry-point follow-up implemented Library::ConsumeRatingsEvent: validation, loading and mapping are coordinated there; EventHandlers::Ratings::RatingSubmitted performs only its reaction. Existing library.completed_ratings subscriber identity is retained. Reviewed production references: LibraryFilm remains inside Library, RatingFilm inside Ratings (including their top-level Rails models); cross-domain consumption uses events and shared user/film IDs.

Entry-point/boundary verification: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/library test/services/ratings test/services/domain_events test/jobs` passed (148 tests / 1,329 assertions). Application eager loading and targeted entry-point/handler/registry RuboCop passed. `git diff --check` passed. Production search found no LibraryFilm references under Ratings services or RatingFilm references under Library services.

Final combined verification before PR: `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci` passed on the final implementation (384 tests / 4,010 assertions; style and security checks clean). This includes all handler/entry-point renames and removal of classification. `git diff --check` passed.

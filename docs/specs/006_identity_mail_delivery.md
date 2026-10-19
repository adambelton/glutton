# 006 — Identity mail previews and delivery configuration

Status: Ready for review  
Owner: Identity / delivery

## Goal

Compose confirmation and password-reset messages through Rails Action Mailer, preview them locally and configure opt-in Resend delivery, with opt-in live development delivery for end-to-end verification and non-network tests/default delivery. Depends on task 004's credential decisions. No other domain contracts are consumed or changed.

Read [the implementation plan](../implementation_plan.md), [product brief, Accounts and privacy](../product_brief.md) and [architecture brief, section 11](../architecture_brief.md). Resend is the selected delivery provider; the application owns account/token behaviour.

## Scope

- Load ignored local development environment files with dotenv-rails; production uses process environment.
- Enable Action Mailer and add a minimal ApplicationMailer plus an Identity-owned account mailer, text/HTML templates and development-only Rails mail previews. Use existing Rails dependencies and conventions; preserve existing project files when generating.
- Compose two messages: confirm registration and reset password. Each contains the supplied link, a clear purpose and text explaining that an unexpected request can be ignored. No names, personal activity, tracking pixels or unsupported expiry claims.
- Provider interface: `Identity::AccountMailer.confirmation(recipient:, confirmation_url:)` and `.password_reset(recipient:, reset_url:)` return normal Action Mailer message delivery objects. Accept a single syntactically plausible email string and a fully qualified HTTP(S) URL; invalid/missing inputs raise ArgumentError before delivery. Use HTTPS for live links; development permits HTTP links only for localhost (including loopback addresses) when SMTP delivery is disabled. Previews use HTTPS example links. Escape template values. No CC/BCC or automatic recipient lookup.
- The caller supplies the recipient and already-authorized link. This task neither creates tokens nor proves mailbox ownership, accepts registration, changes users, consumes tokens or creates sessions. Future Identity workflows must bind tokens to the correct recipient and account; composing/sending mail alone completes no authentication transition.
- Preview both messages with synthetic email addresses and example links, requiring neither accounts in the database nor provider credentials. Inspect rendered HTML and plain text. Previews are accessible only in development via Rails' built-in mail preview routes.
- Development and production support explicit Resend delivery; without opt-in, use the non-network Action Mailer test delivery method. Test always uses the test method even when live settings exist. Local previews remain available in development regardless of selected delivery mode and do not themselves send messages. Use synchronous `deliver_now` for verification; do not enable a job backend or introduce delivery retry infrastructure.
- Opt-in development/production SMTP uses `MAIL_DELIVERY=resend`, `RESEND_API_KEY` and `MAIL_FROM`. Missing/blank required settings in that mode raise a clear configuration error before attempting delivery; unknown mode values fail rather than silently selecting a transport. Non-live mode uses a synthetic example.test sender and needs no secrets.
- Configure Resend through Rails' existing SMTP transport, using the [official SMTP settings](https://resend.com/docs/send-with-smtp): smtp.resend.com, port 587, username resend, API key as password, STARTTLS required and certificate verification enabled. Do not add a provider SDK or write a custom SMTP implementation.
- Raise delivery errors to the caller; do not automatically retry or mark a request confirmed after acceptance by SMTP. Tests replace the SMTP boundary and verify settings/error propagation without a provider connection.
- Keep recipient addresses, credentials, full mail bodies and token-bearing links out of routine application logs, including Action Mailer body logging. Document local preview commands, configuration names and the opt-in live prerequisites without adding secrets or real sender addresses to the repository.

## Scope restrictions

- Identity mail composition/configuration only. No changes to Library, Ratings, Recommendations or Film knowledge; no generic notification/integration layer.
- No registration UI, pending-registration records, token lifecycle, confirmation redemption, password reset/update workflow, guest claim, session changes, account deletion or request-throttling changes. Tasks 006a–006c consume these mailer actions separately.
- Owner-authorized Resend domain setup and DNS verification have been completed separately during this task; no further DNS changes, account/provider signup, API-key creation, paid service or deployment. Development delivery through an already-configured Resend account is in scope for verification. Before any actual send, obtain the owner-designated test recipient and use existing authorized sender credentials; do not send to arbitrary addresses or expose secrets. Record actual live results separately from simulated tests and make no unverified deliverability claim.
- No queue/job configuration, outbox, retry scheduler, webhook, delivery tracking or template editor. Do not persist messages or links solely for preview/testing.
- Use test-local failure injection and standard Rails mail tests rather than creating public diagnostic send endpoints. No production mail preview exposure.
- No commit, publication or merge authorized by this draft. Spec approval does not itself start implementation.

## Acceptance criteria

- **AC1:** Both mailer actions render the correct recipient, sender, purpose and supplied link in HTML/plain text, without changing users or sessions. Invalid recipient/link inputs fail before delivery.  
  Check: `bin/rails test test/mailers/identity/account_mailer_test.rb`; assert headers, multipart contents, escaped values, invalid inputs and unchanged record counts. Record actual results after implementation.  
  Result: Passed — `PARALLEL_WORKERS=1 bin/rails test test/mailers` initially passed 7 tests / 111 assertions; expanded recipient/privacy coverage passed in the final full run (59 tests / 497 assertions). Both messages include the supplied URL, escaped HTML, expected headers and ignore text. Invalid inputs reject before delivery; user/session counts unchanged.
- **AC2:** Built-in development previews render both messages using synthetic values, with no database setup or provider credentials required to generate messages. Previews are disabled outside development.  
  Check: Request `/rails/mailers` and both preview routes through the development Rails application; inspect rendered HTML/plain text. Check production preview disablement on a separate production boot and in configuration tests.  
  Result: Passed — Development `bin/rails runner` with `Rack::MockRequest.new(Rails.application).get(path, "HTTP_HOST" => "localhost")` returned 200 for `/rails/mailers`, `/rails/mailers/identity/account_mailer/confirmation` and `/rails/mailers/identity/account_mailer/password_reset`. Both `Identity::AccountMailerPreview` actions produced HTML/text with ignore text. `RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails runner 'raise if ActionMailer::Base.show_previews; puts ActionMailer::Base.delivery_method'` confirmed previews disabled and default test delivery. Route/content checks were programmatic; no visual browser review claimed.
- **AC3:** Default delivery and all test-environment delivery never contact SMTP. Resend credentials alone do not enable live delivery; development/production require explicit mode plus required settings. Invalid opt-in configuration fails clearly.  
  Check: Configuration tests with isolated environment values; replace/assert the network boundary is not called for non-opted-in/default delivery and all test delivery. Record the exact test command.  
  Result: Passed — Configuration tests cover default development/production, credentials without opt-in, test override despite live/invalid settings, missing/blank credentials, malformed senders and unknown modes. Test mail delivery stayed in memory. Development runner confirmed dotenv-loaded SMTP mode, previews enabled and nil mail logger.
- **AC4:** Opt-in development/production SMTP settings match the documented host, authentication and TLS requirements, and delivery failures propagate without retry or account mutation.  
  Check: Automated tests inspect resolved configuration and intercept SMTP at the boundary to simulate success/failure without a network connection. Also manually send a synthetic message in development to the owner-designated test recipient using configured Resend; record acceptance/error and observed inbox receipt separately. If credentials/sender/recipient are unavailable, mark live verification Blocked rather than Passed. Record exact commands/results.  
  Result: Passed — Configuration/transport tests verify host, port, authentication, required TLS/certificate verification, single-attempt failure propagation and no account/session changes. On 19 October 2026 both templates were sent with development `bin/rails runner` using `.deliver_now` and the owner-designated recipient. Resend SMTP accepted both: confirmation message ID `6ad650069a5ca_46261580158ec@Adams-MacBook-Air.local.mail`; reset ID `6ad65008b47ce_4626158016023@Adams-MacBook-Air.local.mail`. The owner confirmed inbox receipt of both Rails messages on 19 October 2026. The earlier API delivery test was separately confirmed received by the owner.
- **AC5:** Routine logs contain neither recipient/token-bearing body content nor SMTP credentials.  
  Check: Capture logger output using synthetic distinctive recipient, token and API-key markers during test delivery/error handling; assert those markers are absent. Confirm documented settings omit secrets.  
  Result: Passed — Mail logger is nil in every configuration. Logger-capture assertions during test success and simulated SMTP failure omit distinctive recipient, link and credential markers. Documentation contains only synthetic sender/key values; ignored local environment file retains real settings.
- **AC6:** Existing tests, autoloading and CI remain functional with no domain/workflow expansion.  
  Check: `bin/rails zeitwerk:check`, focused mail/configuration tests, `PARALLEL_WORKERS=1 CI=true bin/ci`, `git diff --check` and scope review. The one-worker command accommodates the previously observed native macOS fork failure; do not claim default parallel execution passed without running it.  
  Result: Passed — `PARALLEL_WORKERS=1 CI=true bin/ci`: 59 tests / 497 assertions, no failures/errors/skips; 48 Ruby files linted cleanly; gem/importmap audits clear; Brakeman zero warnings. `bin/rails zeitwerk:check` passed (Rails notes preview directory is not eager loaded; preview classes/routes were exercised separately). `git diff --check` passed. Initial sandboxed test attempt could not reach PostgreSQL; rerun with local database access passed. Local default parallel execution was not run. Hosted CI initially exposed the existing serial-only database smoke assertion; Foundation task 001c fixes it separately. [Hosted CI run 39293312855](https://github.com/adambelton/glutton/actions/runs/39293312855) then passed with four workers: 59 tests / 498 assertions, 48 Ruby files linted cleanly and security checks clear.

## Implementation notes

Enabled Action Mailer with minimal base/account mailers, multipart templates, built-in previews and explicit Resend SMTP configuration. Added development-only dotenv-rails loading, non-network defaults/test override, configuration validation and privacy/failure tests. Updated README and briefs. Local ignored development settings now opt into the verified sender; production still needs explicit process configuration.

Owner authorized implementation after successful domain setup. The domain was added in Ireland; the owner added Cloudflare DNS records and DMARC. Earlier API test receipt is confirmed; the Rails SMTP tests above separately verify the application transport, and the owner confirmed receipt of both Rails messages. No new account/token/session workflow, job backend, endpoint, deployment or merge.

Reproduce live verification only with an authorized recipient: set `MAIL_TEST_RECIPIENT` in the process environment, then run:

```sh
bin/rails runner 'raise unless Identity::AccountMailer.delivery_method == :smtp; { confirmation: :confirmation_url, password_reset: :reset_url }.each { |action, argument| message = Identity::AccountMailer.public_send(action, recipient: ENV.fetch("MAIL_TEST_RECIPIENT"), argument => "https://example.test/mail-verification?token=synthetic-preview").deliver_now; puts "#{action}: SMTP accepted; message_id=#{message.message_id}" }'
```

The synthetic links are intentionally nonfunctional. Inbox receipt of both Rails messages is confirmed by the owner. Authentication-header inspection (SPF/DKIM/DMARC results) has not been reported; SMTP acceptance and inbox receipt do not by themselves verify those header results.

Owner acceptance / merge: Pending.

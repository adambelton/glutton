# Codebase audit — 20 October 2026

Status: Merged  
Owning supporting area: Foundation / repository review  
Task: [001f](../specs/001f_codebase_audit.md)  
Baseline: `main`, `3cd3034e0e48fe04648c8a36c4e1d0028a622270`

`git pull --ff-only origin main` reported “Already up to date”; the initial working tree was clean. This review covers implemented Identity, Film knowledge and Library behaviour, their tests, persistence, configuration and maintained guidance. Ratings and Recommendations remain planned.

The organisation is sound for the current application size. Keep the Rails monolith, top-level models and domain-namespaced operations. The principal actionable defect is an Identity concurrency gap between credential verification and session issuance. The other observations concern duplicated policy and documentation drift, not a need for new domain boundaries or a generic framework.

## Subsequent remediation

The findings and verification below describe the original audit baseline. The owner subsequently authorized fixes and confirmation simplification, implemented in [006o](../specs/006o_authentication_reset_serialization.md) (A1), [006p](../specs/006p_confirmation_orchestration.md) (A2), [009b](../specs/009b_tmdb_boundary_consistency.md) (A3), and [001g](../specs/001g_current_documentation.md) (A4). These fixes and subsequent confirmation follow-ups were accepted and merged via PR #22 on 20 October 2026. Final local CI passed 232 tests / 2,633 assertions, style and security checks; application eager loading passed. See the individual specs for reproduction commands, limitations and the initial failing authentication regression.

## Findings

### A1 — High: serialize sign-in with password reset (Identity)

Sources: `app/services/identity/authenticate.rb:4–5`, `app/models/user_registered.rb:15–24,27–35`, `app/models/session.rb:37–39`, `app/controllers/sessions_controller.rb:12–16`.

Authenticate reads and verifies credentials, then creates a Session separately. ResetPassword locks the user, changes the digest and removes existing sessions. Authentication does not participate in that user lock; Session validation only rechecks that the owner is active. The controller's transaction alone does not serialize these operations.

A sign-in can therefore validate the old password, pause, allow password recovery to finish revoking sessions, then create a fresh active session using its earlier credential result. This violates the intended recovery outcome for an in-flight old-password sign-in. The invariant belongs wholly to Identity; there is no cross-domain design problem.

**Evidence:** A deterministic two-connection probe paused the actual credential method immediately after successful verification, completed the real reset operation, and resumed the actual Authenticate operation inside the same transaction wrapper used by the sign-in controller. Result:

```json
{"old_password_rejected_now":true,"issued_session_still_active":true,"session_count_after_reset":1}
```

The existing 227-test suite passes. `test/services/identity/password_recovery_concurrency_test.rb` covers concurrent token redemption and delivery lock boundaries, but not sign-in racing recovery.

**Recommendation:** In a separate Identity task, make credential validation/session issuance and reset share a serialization boundary on the user, revalidating the credentials under that boundary. Merely locking after authentication without revalidation is insufficient. Verify both orderings: a sign-in committed first is revoked by reset; a reset committed first prevents issuance with the old password. Keep credential rules on the model and coordination in the Identity operation.

### A2 — Medium maintainability: confirmation eligibility is duplicated in HTTP and workflow code (Identity)

Sources: `app/controllers/registration_confirmations_controller.rb:7–20`, `app/services/identity/complete_browser_registration.rb:7–18`; compare `app/services/identity/resolve_password_reset.rb:3–15` and `app/controllers/password_resets_controller.rb:66–68`.

Confirmation GET interprets the token, current user's registration permission, linked-user ownership and browser pending-registration ownership directly in the controller. Confirmation POST independently expresses the same eligibility policy in its workflow. Password recovery already has a clearer separation through its resolution operation.

No current GET/POST disagreement was demonstrated. The concern is that an ownership-policy change must be reproduced in two differently structured branches, leaving HTTP responsible for a domain decision. Rechecking fresh state during mutation is necessary; duplicating the rule is not.

**Recommendation:** Give confirmation eligibility one Identity-owned behavioural implementation that both read-only resolution and locked completion can use. Keep GET side-effect-free and retain fresh locked checks during POST. Do not reuse a GET result as authorization for a later POST or introduce a general authorization framework. Verify anonymous, matching guest, unrelated guest, registered user, unattached browser-owned request and stale/expired cases.

### A3 — Low maintainability: TMDB parsing and validation responsibilities are uneven (Film knowledge)

Sources: `app/services/film_knowledge/import_tmdb_film.rb:15–26`, `app/services/film_knowledge/search_tmdb_films.rb:18–28`, `app/services/film_knowledge/search_tmdb_films.rb:4`, `app/services/film_knowledge/tmdb_client.rb:10–21,34–35`.

Import and search duplicate the complete release-date parser and error policy. Search also reaches directly into the concrete TmdbClient validator even when given another client; with the default client, the same input validator executes at operation, class-client and instance-client levels. The validation itself is appropriate for untrusted inputs, and the current date semantics agree.

**Recommendation:** When next changing these rules, give the shared date semantics one small Film knowledge implementation and clarify which public entry points validate search inputs. Preserve validation-before-network behaviour and direct-client safety. This is a local cleanup opportunity, not justification for provider interfaces, generic HTTP infrastructure or a shared cross-domain validation layer.

### A4 — Low: maintained guidance mixes current decisions with obsolete status (Foundation)

Sources: `docs/architecture_brief.md:47–51,292–301`, `docs/implementation_plan.md` opening status and “Conventions fixes authorized after task 010”, `README.md:5`.

The architecture brief still lists confirmation of Rails/PostgreSQL and frontend selection as open, despite recording and implementing Rails/PostgreSQL/server-rendered Hotwire. The plan's opening summary omits later merged convention fixes, while an earlier paragraph says those fixes are implemented for review and the later table says Merged. README's introduction still describes only the initial home/health scaffold, although later sections document authentication and catalogue operations.

**Recommendation:** Refresh current summaries and open decisions while retaining historical specs and merge evidence. Make one current-status section authoritative and link to it. Separate settled framework choices from genuinely open deployment/job decisions. This needs only a Foundation documentation task.

## Organisation and convention assessment

| Area | Assessment and evidence |
| --- | --- |
| Rails organisation | Consistent default model paths; STI roots/subtypes use matching file and constant names. Operations and errors are grouped under Identity, FilmKnowledge and Library. No engines, generic repositories, empty capability modules or integration layer. Zeitwerk passes application eager loading. More namespaces would add ceremony at this size. |
| Domain ownership | Film knowledge does not inspect viewers or Library. Library's RecordWatched owns its transition, uses fresh User/Film reads and delegates permission to `can_watch?`. Its user lock coordinates with Identity cleanup/claim through the established task 010 contract. The scoped Library foreign-key cascade is explicitly agreed and tested; it is not an accidental Identity ownership leak. No implemented Ratings/Recommendations behaviour to evaluate yet. |
| Roles and behaviour | User permissions and credential actions reside on models; STI transitions remain in services. Polymorphic user partials avoid controller subtype dispatch. Runtime class checks largely validate external inputs, JSON/schema shape, root construction or targeted persistence failures; removing them mechanically would weaken boundaries. A2 is the clearest remaining placement concern. |
| Outcomes and persistence | AlreadyWatched is an explicit failure. Import deduplicates according to its agreed system contract. Unique indexes, foreign keys, credential constraints, transactional rollback and real PostgreSQL race tests provide substantial protection. A1 shows that individually transactional operations still need a shared concurrency invariant. |
| UI and i18n | Inspected application templates, controller responses and mail use runtime locale lookups; custom validations use symbols. Development/test enable strict missing-translation errors. Domain exception diagnostics remain developer-only in current implemented flows. No broad hard-coded application-copy violation found. |
| Tests | Strong outcome, rollback, replay, expiry, ownership and real-provider-contract coverage. Schema/type assertions that verify declared STI/storage contracts are appropriate. Existing selective credential snapshots verify preserved invariants rather than whole-row incidental state. The significant omission is the A1 cross-operation race. |

Do not consolidate every short service merely to reduce file count. Registration preparation, browser coordination, confirmation transition and delivery have distinct transaction/transport responsibilities. Similarly, keep the directly declared model validations: the architecture explicitly rejects extracting modules merely to share declarations.

## Existing limitations, not newly discovered convention violations

- Per-worker authentication/registration/recovery rate limits are explicitly documented as requiring shared controls before multi-worker release.
- Cleanup scheduling, account deletion, public deployment and later domain activity retention remain scoped future work.
- Live TMDB compatibility, mail delivery, browser interaction/accessibility and production readiness were not established by this audit.
- The review is evidence-based sampling of test intent and maintained task specs, not a proof of every possible interleaving or exhaustive security assessment.

## Verification

| Check actually run | Result |
| --- | --- |
| `git status --short --branch`; `git pull --ff-only origin main`; `git rev-parse HEAD` | Clean starting main; already up to date; baseline above. Pull required sandbox elevation to write FETCH_HEAD. |
| `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test` | **Passed:** 227 runs, 2,596 assertions, 0 failures/errors/skips, seed 55977. Initial sandbox attempt could not connect to local PostgreSQL; rerun with approved access passed. |
| `bin/rubocop --cache false` | **Passed:** 125 files, no offences. Sandbox attempts could not inspect the existing RuboCop server process; approved rerun passed. |
| `RAILS_ENV=test bin/rails zeitwerk:check` | **Passed** for application eager loading; tool explicitly excludes `test/mailers/previews` from this check. |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` | **Passed:** 0 errors, 0 warnings (locked Brakeman 8.0.6). |
| `RAILS_ENV=test bin/rails runner /tmp/glutton_audit_auth_race.rb` | **Confirmed A1:** output above. Synthetic test records cleaned up; separate connection, actual authentication/reset operations. |
| `git diff --check` and final file-status inspection | **Passed:** documentation-only changes for this review. |

Dependency vulnerability refreshes (`bundler-audit`/`importmap audit`), the combined setup/CI command and hosted CI were **not run**. No application fix, dependency change, external send, deployment, commit, PR or merge was performed.

## Reproduce A1

Save the following as `/tmp/glutton_audit_auth_race.rb`, then run `RAILS_ENV=test bin/rails runner /tmp/glutton_audit_auth_race.rb` against the disposable local test database. The barrier wraps the existing credential operation without changing its result; cleanup removes the synthetic account and session. This is audit evidence, not a committed regression test.

```ruby
require "timeout"
raise "test only" unless Rails.env.test?
user = UserRegistered.create!(email_address: "audit-#{SecureRandom.hex(8)}@example.test", password: "original audit password", password_confirmation: "original audit password", email_confirmed_at: Time.current)
ready = Queue.new
continue = Queue.new
original = UserRegistered.method(:authenticate_credentials)
UserRegistered.define_singleton_method(:authenticate_credentials) do |**credentials|
  authenticated = original.call(**credentials)
  ready << true
  Timeout.timeout(5) { continue.pop }
  authenticated
end
begin
  token = user.password_reset_token
  contender = Thread.new do
    ActiveRecord::Base.connection_pool.with_connection do
      Session.transaction do
        Identity::Authenticate.call(email_address: user.email_address, password: "original audit password")
      end
    end
  end
  Timeout.timeout(5) { ready.pop }
  Identity::ResetPassword.call(token: token, password: "replacement audit password", password_confirmation: "replacement audit password")
  continue << true
  authentication = Timeout.timeout(5) { contender.value }
  puts({ old_password_rejected_now: !user.reload.authenticate("original audit password"), issued_session_still_active: authentication.active?, session_count_after_reset: Session.where(user_id: user.id).count }.to_json)
ensure
  continue << true
  contender&.join(5)
  contender&.kill if contender&.alive?
  UserRegistered.define_singleton_method(:authenticate_credentials, original)
  Session.where(user_id: user.id).delete_all
  user.delete
end
```

Owner acceptance / merge: Accepted by the owner and merged via [PR #22](https://github.com/adambelton/glutton/pull/22) on 20 October 2026 at 16:52:53 UTC. Squash commit `5c7279a349bfe187c2c60f6db6727b0171e6995f`; hosted Repository checks passed for head `50b937f9da7245b457f6fffc83b72ddd416a832e` before merge.

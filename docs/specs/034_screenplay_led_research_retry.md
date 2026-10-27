# 034 — Simplify source admission and try screenplay-led research

Status: Accepted — owner authorized merge after hosted CI, 27 October 2026  
Owner: Film knowledge

## Goal

Remove the explicit page-open validation rejected by the owner, record screenplay-led research with independent finished-film corroboration, and retry The Thing once. Prerequisites: task 033 evidence and tasks 031/031a. Owner authorized this correction and another attempt on 27 October 2026; reuse the agreed model/output/tool budgets.

## Scope

- Remove `opened_urls` and the response/tool-history dependency from generated-document parsing. Do not replace it with another retrieval-history gate. Keep tool history in artifacts/traces for diagnostics. Retain source shapes, valid URLs, OpenSubtitles exclusion, reference integrity, two independent origins for factual claims and existing caption rules.
- Add screenplay as an explicit source kind. Update the managed development prompt: prefer a screenplay as a narrative backbone, distinguish its draft/version from the finished film, and corroborate retained events/details using an independent finished-film account. Copies/derivatives of a script count once. Screenplays do not prove final performances, editing, sound or audience response. Search-returned substantive passages may support a claim without a separate open action; listings/snippets that do not establish the claim cannot. Trust the model's source reading and semantic assessment rather than inventing a validator proxy for it.
- Record the decision in evidence requirements, architecture brief and current protocol. No bulk corpus acquisition or new provider integration. Source availability remains model-led; missing screenplay coverage is a reported gap, not an invented script or a new manual preparation stage.
- Verify with fake responses, full CI and eager loading, then publish/retrieve the updated development prompt. Preserve historical versions and all prior artifacts.
- Execute one new development attempt for The Thing (TMDB 1091), `gpt-5.5-2026-04-23`, 16,000 output tokens, 12 tool calls, 180-second timeout and zero retries. Check no analysis exists, pin the new prompt/hash, retain the original artifact, audit result/persistence/remote trace and report actual support/limitations.

## Scope restrictions

- Film knowledge only. No schema/dependency changes, new service/provider integration, full corpus download, additional source subscriptions, Batch probe/bulk seed, publication, existing-analysis regeneration or downstream changes.
- At most one new billable request. No further retry or prompt tuning during the live attempt. Do not modify/apply the previous rejected output or weaken the two-source requirement.
- Do not claim structural checks establish semantic entailment or independence. Do not require a human review step to supply missing initial-seed evidence.

## Acceptance criteria

- **AC1:** Source admission no longer depends on explicit tool-page opens.
  Check: remove the response argument/history predicate; valid source-supported documents save with no open records. Malformed references, copied origins and one-source facts still fail atomically. Screenplay/review evidence is representable.
  Result: Passed. Removed the response argument and `opened_urls` predicate entirely, with no replacement tool-history gate. Full-suite coverage verifies valid documents save with an empty page-open history, a screenplay/review source pair is representable, and malformed URLs, copied origins, one-source facts, invalid references/candidates and caption rules remain enforced.
- **AC2:** The screenplay decision and compatible managed prompt are recorded.
  Check: compare exact retrieved/published text/hash/config, preserve quality guidance and OpenSubtitles exclusion, record screenplay version/finished-film corroboration rule in brief/requirements/protocol.
  Result: Passed. Managed development prompt v6 published/retrieved exactly, contract `researched-analysis-v1`, SHA-256 `1c945160e6c8014b4f263e6c2b4aa178c7aadb1ce129eb601059845daef5f7cb`; development/latest labels, no production label. Evidence requirements, architecture brief and protocol now record screenplay-led narrative with independent finished-film corroboration and substantive search content accepted without an explicit open. Quality guidance and OpenSubtitles exclusion remain.
- **AC3:** Local verification passes before spending.
  Check: focused tests, `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`, eager loading and `git diff --check`. Record actual commands/results.
  Result: Passed. Final `RAILS_ENV=test PARALLEL_WORKERS=1 CI=true bin/ci`: 534 tests / 5,665 assertions, zero failures/errors/skips; RuboCop (254 files), gem/importmap audits and Brakeman (0 warnings) passed. `RAILS_ENV=test bin/rails zeitwerk:check` passed with standard mailer-preview exclusion notice; `git diff --check` passed. Initial CI found one test-file blank-line offense, fixed before the final passing run. Focused coverage ran within the full suite; no separate focused command is claimed.
- **AC4:** One authorized retry has a reviewable result.
  Check: record baseline, one command, raw response/tool history and hash; reconcile saved draft or actual failure, unchanged Alien/shared qualities and remote observations. Review script use and claim support without editing output. Update report/plan; mark Ready for review without self-acceptance/merge.
  Result: Passed. The one prompt-v6 retry saved unpublished FilmAnalysis 2. Original content/six candidates match persistence exactly; counts moved from 1/0/0 to 2/0/0 and generation is now ineligible. Alien and both earlier artifacts remain unchanged. The model used Bill Lancaster second-draft screenplay with released-film corroboration and explicitly excluded uncorroborated script ending material. Remote trace hierarchy, prompt/input/output/settings/actions/model/usage/saved outcome reconcile. Usage 85,865 input / 6,262 output (2,890 reasoning); Langfuse model-token cost USD $0.617185 plus estimated four-search $0.04, subtotal $0.657185, not invoice-reconciled. Selective narrative coverage and support-granularity limits remain documented in the [report](../research/generated_analysis_verification/the_thing_screenplay_retry.md).

## Implementation notes

Implemented the requested simplification and prompt/source-kind update. Preflight verified The Thing has no existing analysis, baseline counts 1/0/0, and the pinned v6 hash before the one authorized retry. That single request completed and saved unpublished analysis 2; no further retry occurred. Model/tool documentation consulted for task 033 remains applicable; this task changes source admission and prompt instructions, not provider request settings. Use the existing Langfuse/OpenAI docs workflows. The owner's pragmatic correction supersedes earlier specs/protocol language requiring an explicit completed `open_page` for every source.

Owner acceptance / merge: Pending. One new paid retry is authorized; no publication or bulk execution.


## Final evidence

[Screenplay-led retry report](../research/generated_analysis_verification/the_thing_screenplay_retry.md) records reproducible commands, original artifact/observation hashes, actual screenplay use, persistence assertions, trace reconciliation and editorial limits. The UUID artifact is `tmp/film_analysis_runs/099fd1b4-e632-4b39-8ff2-3cab5df48f65.json`, SHA-256 `b58604dfd2626da0432199f665437d0b3e48338d4ad385e7a637625ad3b832ad`. The report separates successful saving from full narrative completeness. Tool history is retained without being an admission gate. No new validation mechanism, human approval workflow, publication, Batch probe or merge was introduced.

Ready for review. Owner acceptance / merge: Pending.


## Owner acceptance — 27 October 2026

The owner authorized a PR covering the completed research-generation implementation, source decisions and evaluation reports, with merge only after hosted CI passes. Earlier pending statements record the pre-acceptance history. This authorization does not permit another paid evaluation, publication, bulk seed or deployment.

# 026a — Record comparison layers and historical validity

Status: Merged via PR #40  
Owner: Supporting architecture / design documentation

## Goal

Record the owner's podcast, comparison and version-history decisions consistently, and prepare a bounded repeat of the Film knowledge pilot. Documentation only; no cross-domain runtime work.

## Scope

- Define standalone analysis, recommendation/profile comparison and review/expression comparison as separate layers.
- Record the episode flow, evidence references and historical reproduction requirements.
- Record analysis activation, timestamped supersession for analyses and ratings, retained quality associations/scores and self-explanatory quality names.
- Reconcile current implementation versus future design and prepare task 027 using the task template.
- Finalise the V1 author-neutral draft/candidate/activation workflow and domain ownership, including Recommendations-owned persisted quality contributions. Keep community verification and expression feedback as future work.

## Scope restrictions

- No models, migrations, scoring engine, UI, jobs, domain communication or new synchronous contracts.
- No podcast production, scheduling, publication, recordings or invented host preferences.
- No rating drafts, user commitment step or rating activation. No mandatory quality-description field or generic versioning framework.
- Preserve existing pilot artifacts and verification as historical evidence. Do not claim the new pilot or engine evaluation has run.

## Acceptance criteria

- **AC1:** Docs consistently describe the agreed boundaries and lifecycle.
  Check: trace the three layers, episode order, analysis activation, rating immediacy, timestamp validity and retained inputs across requirements, scoring design and briefs.
  Result: Passed — manual cross-document review on 27 October 2026: the episode order and three layers are explicit; analyses remain viewer-independent; activation applies only to validated analyses; ratings remain immediate with planned timestamped supersession; historical association/score retention and no backdated processing are recorded. Current latest-ID implementation is distinguished from planned changes.
- **AC2:** A repeat-pilot spec tests the new analysis requirements without pretending scoring exists.
  Check: inspect task 027 scope, same-film sample, evidence requirements, version scenario and explicit dependencies for actual engine/profile comparisons.
  Result: Passed — task 027 remains Draft, uses the same five films and preserves the prior dossiers. It tests narrative/moment references, association sets, labelled expression probes and an illustrative validity timeline. It explicitly excludes invented host data, numeric predictions and claims of running the real engine.
- **AC3:** References resolve and changes remain documentation-only.
  Check: local Markdown link/anchor validation, git diff --check and git status --short.
  Result: Passed — Python resolved 151 local links/anchors across 15 documents; git diff --check passed. git status --short confirms documentation-only changes, preserving earlier task 023b merge evidence. No runtime tests or pilot rerun were performed.

- **AC4:** Final V1 decisions are consistent and preserve the completed pilot evidence.
  Check: inspect the V1 draft/candidate/activation workflow and ownership table; confirm Recommendations persists its own scores and separate community verification is deferred. Run the task 027 verifier, resolve local documentation links/anchors and run `git diff --check`.
  Result: Passed — 27 October 2026. Manual review of requirements, scoring design, product/architecture briefs and plan confirms these decisions. `python3 docs/research/comparison_pilot/verify.py` passed six baseline hashes, 196 local links/anchors, twenty associations and thirteen historical selections. A Python relative-link/heading/HTML-anchor check passed 352 references across 24 changed/supporting Markdown documents. `git diff --check` passed. No runtime tests were run locally; hosted repository CI will gate the requested merge.

## Implementation notes

Owner requested docs/spec updates following the podcast and lifecycle discussion. Existing ratings use latest-ID currentness; the new lifecycle remains a future implementation decision.

Owner acceptance / merge: Pending.

Verification reproduction: inspect the requirements, scoring design, both briefs, plan, tasks 025/026/026a/027 and six pilot Markdown documents. Resolve each relative Markdown target from its containing directory and each fragment against the target headings; external URLs are excluded. Run `git diff --check` and `git status --short`. For the manual lifecycle check, consider a pending analysis replacement, its activation boundary, an immediate rating replacement and a later completed profile-driven reassessment. Confirm that the docs never treat a draft or unfinished calculation as historically active.

Final owner-authorised closeout: the V1 workflow accepts human or AI drafts, editable candidates and atomic resolve/create/link activation; revisions retain history. Recommendations-owned saved contributions supersede the earlier reconstruction-only design. Independent community review and expression feedback remain deferred. Tasks 026/027 remain historical research evidence, not claims of production activation or recommendation accuracy. The owner authorised PR creation and merge after CI on 27 October 2026.

Merge record: owner authorised merge after CI; merged via [PR #40](https://github.com/adambelton/glutton/pull/40) on 27 October 2026 at 11:58:21 UTC after hosted checks passed on `46873e53c51a1aed48551f63d65dc09e384bbfce`. Earlier status/evidence above describes the pre-merge deliverable. Research acceptance does not assert production accuracy or independent curator verification.

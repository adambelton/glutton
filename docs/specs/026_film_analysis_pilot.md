# 026 — Evaluate experiential analysis on five films

Status: Merged via PR #40  
Owner: Film knowledge / analysis evaluation

## Goal

Use real-film research to evaluate task 025's provisional analysis requirements before implementing the pipeline. Owner requested the pilot and selected Bone Tomahawk (2015), Terrifier (2016), The Babadook (2014), Alien (1979) and Scream (1996).

## Scope

Owner-approved revision: the initial drafts were too conclusion-focused. Expand all five into evidence-led dossiers: chronological narrative with causal transitions, detailed key moments with context/action/consequence, source-specific support and gaps, then experiential synthesis. Preserve the original film selection and documentation-only boundary.

- Research the five selected films using accessible sources; target original theatrical versions and identify any uncertainty about source versions.
- Produce five original, source-linked draft analyses covering all seven experiential dimensions, narrative through the ending, significant sequences, contrasting interpretations and evidence gaps.
- Distinguish reported observations, reported experiences, external facts and synthesis. Seek independent support without pretending all claims have it.
- Compare a small set of film-derived candidate qualities, assess their usefulness and identify weaknesses in the requirements.
- Record source provenance, access limitations, review rubric outcomes and revisions justified by the pilot in docs/research/analysis_pilot/.
- Update task 025 requirements and plan from actual findings, retaining their provisional status where untested.

## Scope restrictions

- Research/docs only. No application changes, database imports, migrations, credentials, paid services, model API calls, source archives, scripts/subtitle downloads or deployment.
- No claim of having watched the films, independent curator approval, confirmed source licences for production ingestion or measured recommendation accuracy.
- Do not invent TMDB IDs or silently mix original films, sequels, remakes or alternate cuts. TMDB integration remains the future metadata backbone; this pilot does not validate that integration.
- No fixed production taxonomy, scoring, community feedback or pipeline implementation. Qualities are hypotheses, not seed data.
- User selection replaces the earlier proposed sample. Its English-language bias is a limitation, not a reason to substitute films.

## Acceptance criteria

- **AC1:** Five evidence-led dossiers provide chronological plot breakdowns through the ending and detailed key moments before experiential conclusions. Each moment identifies context, action, consequence, source support, reported response where available and gaps.
  Check: inspect each film for identity/version, narrative outcome, seven dimensions, specific sequences, claim support and source provenance.
  Result: Passed in author review on 27 October 2026 — each dossier now has seven chronological phases and six detailed moments before synthesis. The narratives cover setup, decisions, reversals and endings; moments identify source support, consequences, responses and gaps. Registers contain 32 sources across 33 URLs. This supersedes the initial field-coverage pass, which owner review found insufficient. Exact cuts and comprehensive corroboration remain unverified; owner depth acceptance is pending.
- **AC2:** Cross-film comparison tests the usefulness and limitations of dimensions and candidate qualities.
  Check: produce a matrix with supported, tentative and unknown associations, examine overlap without asserting predictive value, and apply the review rubric.
  Result: Passed — the report compares eight candidate qualities across five films using supported/tentative/not-established associations and applies a nine-criterion self-review rubric. Broad humour and unsecured-survival candidates need refinement; recommendation usefulness remains a hypothesis.
- **AC3:** Findings produce concrete requirement changes with honest limits.
  Check: link changes to film examples; distinguish real source evidence from analyst hypotheses, missing source coverage and untested implementation concerns.
  Result: Passed — eight findings are tied to film/source examples. Requirements now explicitly distinguish claim scope, depicted content, response holders, inference, support status and evidence needed to close gaps. No predictive evaluation, direct viewing or production ingestion validation is claimed.
- **AC4:** Research artifacts are navigable and scope remains documentation-only.
  Check: validate local links/anchors and git diff --check; inspect git status. Record commands/results. No runtime tests required.
  Result: Passed on 27 October 2026 — `python3 /tmp/verify_analysis_pilot.py` checked 12 documents, 140 local links/anchors, 35 narrative sections, 30 moments, seven dimensions per film, 32 source identifiers and 33 distinct URLs. It also checked section order and duplicate/unresolved source labels. `git diff --check` passed; `git status --short` remains documentation-only, including preserved task 023b evidence. No runtime tests were run.

- **AC5:** Evidence depth is a requirement, not merely seven filled dimension fields.
  Check: verify that a reader can reconstruct major causal developments from the narrative and inspect concrete evidence underlying conclusions; mark unsupported details and uncorroborated claims explicitly.
  Result: Passed in author self-review — traced Samantha’s treatment to abduction/rescue, Tara’s delayed ride to entry/capture, Amelia’s isolation to the caregiving reversal, quarantine failure to the crew’s losses, and Sidney’s changing evidence about Billy to the reveal. Each dossier now supports that causal reading before presenting qualities. Scene-specific gaps are retained; word counts and section counts alone are not acceptance evidence.

## Implementation notes

Owner authorised research on 27 October 2026. Completed five source-based drafts and the [comparison/report](../research/analysis_pilot/README.md); revised task 025 requirements from the findings. Owner requested greater narrative/evidence depth and approved revision on 27 October 2026. The revision adds evidence-led requirements and expanded dossiers, corrects the Buddy/Purvis allegation, and excludes an Alien later-cut scene from the theatrical account. No independent review has occurred.

Verification reproduction:

- Run `git diff --check` and `git status --short` from the repository root.
- In the requirements, briefs, plan, tasks 025/026 and six pilot Markdown documents, resolve each relative Markdown link against its containing directory and compare any fragment to the destination heading. External URLs are excluded from this local-link check.
- In each of the five film drafts, confirm the seven named dimension rows, resolve every source label against its local register, and count 32 source entries across 33 distinct URLs. Confirm seven narrative phases and six moments per dossier, with narrative and evidence preceding synthesis.
- Inspect the report's eight candidate rows, original eight findings, revision findings and rubric against the linked drafts. These are self-review checks, not source-independent verification.

Limitations: English-language owner-selected sample; no direct film viewing, verified cuts, scripts/subtitles, pinned source revisions, independently accepted analysis or measured preference prediction. These constrain the conclusions and are recorded in the report.

Owner acceptance / merge: Pending.

## Follow-up evaluation

Revision 2 remains the source-based baseline. The subsequent podcast/comparison and historical-validity decisions were not evaluated by its recorded checks. Task [027](027_comparison_ready_analysis_pilot.md) proposes a separate run, preserving this baseline and distinguishing analysis-readiness probes from an actual engine evaluation.

Merge record: owner authorised merge after CI; merged via [PR #40](https://github.com/adambelton/glutton/pull/40) on 27 October 2026 at 11:58:21 UTC after hosted checks passed on `46873e53c51a1aed48551f63d65dc09e384bbfce`. Earlier status/evidence above describes the pre-merge deliverable. Research acceptance does not assert production accuracy or independent curator verification.

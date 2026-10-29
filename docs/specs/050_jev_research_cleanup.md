# 050 — Retire JEV tuning artifacts and retain the working baseline

Status: Ready for review  
Owner: Film knowledge

## Goal

Leave a small, usable vocabulary/matching baseline and six review examples, removing the tuning work that is no longer a prerequisite to progress. Prerequisites: implementation plan, task template, current film-quality/product requirements, experiment findings and vocabulary-evolution notes read. Owner authorised discarding unnecessary JEV tuning artifacts; the later Langfuse question does not cancel cleanup.

## Scope

- Preserve all 235 currently tested quality identities, names, categories, definitions and exclusions in one maintained location, with a human-readable list and the exact shared matching template/evidence policy.
- Retain six source-provenanced uncapped examples: original source paragraphs, all support probabilities and the 318 matched-candidate review records, plus a compact run receipt. Preserve a concise findings/limitations summary instead of tuning reports and matrices.
- Remove the five superseded JEV/vocabulary research trees, their duplicated vocabulary/sources/requests/traces/audits/replay scripts, and tuning-only specs 044, 045, 048, 049. Remove only the five known ignored JEV scratch directories: master_quality_vocabulary, jev_selection_experiment, jev_support_importance, jev_neutral_context, jev_quality_feasibility.
- Repair maintained documentation and historical record references; consolidate plan status. Record selection/community review as the next design work, not more fine tuning as a release prerequisite. Keep task 043's category implementation scope unchanged.
- Keep the shared question template and product quality meanings in the project. Existing Langfuse traces remain available; no prompt migration is needed for this step. Future template management remains optional, not a new source of truth for community-owned quality definitions.

## Scope restrictions

- No paid requests, external service mutation, prompt migration, production code/schema/data changes, new accepted qualities, score changes or UI/workflow implementation. Do not settle max-20 selection or community publishing details in a cleanup task.
- Do not rename/redefine/add/remove qualities. Retention can update stale editorial status metadata, but must preserve all five per-quality fields exactly.
- Preserve unrelated changes, earlier authorised LLM-document deletions, .agents/, .obsidian/, AGENTS.md, skill installation/lock and all credentials. No broad tmp cleanup; non-JEV source/LLM scratch directories remain outside scope. No merge/self-acceptance.

## Acceptance criteria

- **AC1:** The working baseline and useful examples survive without meaning changes.  
  Check: compare all 235 five-field records, matching questions/policy reconstructed from the retained contract, six source/title/paragraph packets, all 1,410 probabilities and all 318 matched reviews against pre-cleanup inputs.  
  Result: Passed. Before deleting old files, a Python comparison verified exact equality of all 235 five-field quality records, reconstructed all 235 tested questions and the shared evidence policy, and compared each retained title/source-paragraph packet, all 1,410 probabilities and the 318 matched-candidate review records. The same check passed after deletion. New baseline: `docs/film_qualities/`; concise findings: `docs/research/film_quality_findings.md`. Editorial status metadata alone was updated to reflect the completed six-film test.
- **AC2:** Superseded tuning artifacts are removed and docs lead into the next work.  
  Check: explicit removal allowlist absent; all local Markdown links/anchors resolve; maintained docs no longer recommend replay/tuning as a blocker. Summary retains actual cost/results and review limitations, with no new production rules.  
  Result: Passed. Explicit allowlist removal deleted 274 research/scratch files (26,200,456 bytes) across the five research and five JEV scratch trees, plus four tuning-only specs. All ten roots are absent. Canonical requirements, product/architecture briefs and plan point to the retained baseline and selection/community-review direction. Retained task records explicitly mark former commands/artifact paths as historical. Repository Markdown file/anchor checks passed all 254 surviving local links/anchors.
- **AC3:** Cleanup remains documentation/data only.  
  Check: before/after production diff, unrelated-file hashes, whitespace including new files; retain reproducible manual verification instructions and actual evidence here. Update plan and Ready for review. No runtime/provider checks required or claimed.  
  Result: Passed. `git diff -- app db test config lib` matched its unchanged before snapshot (empty). Seven protected-file hashes (AGENTS.md, skill lock/content and stable Obsidian settings) remained unchanged. `.obsidian/workspace.json` changed during the task without any tool writing it; its latest state was preserved, not reverted. `git diff --check` and explicit whitespace checks on new files passed. No application/runtime tests, provider calls, external service updates or migration were performed. Full local check executed as `python3 /tmp/glutton-050-check.py`; its result is recorded in this spec. Owner acceptance/merge remains pending.

## Implementation notes

Consolidated the useful material into five working-baseline files and one concise findings note. Removed old tuning trees, replay scripts, duplicate vocabulary, detailed comparison/audit outputs, the allowed ignored scratch directories and tuning-only specs; remote Langfuse traces and unrelated LLM/source scratch remain untouched. This is a documentation/data cleanup, not implementation of selection/community publishing or removal of legacy FilmAnalysis models. Added the explicit decision that no Langfuse prompt migration is required now and kept community-maintained quality meanings local as product data. No quality meanings, identities, categories or current app behaviour changed.

## Reproducible retained-data check

From the repository root, this checks the retained vocabulary against its pre-cleanup canonical hash and the surviving example coverage/links. The full before/after comparison used the temporary snapshot before deleted artifacts were discarded.

```sh
python3 - <<'PY'
from pathlib import Path
import hashlib, json
root = Path("docs/film_qualities")
qualities = json.loads((root / "vocabulary.json").read_text())["qualities"]
encoded = json.dumps(qualities, ensure_ascii=False, separators=(",", ":")).encode()
assert hashlib.sha256(encoded).hexdigest() == "31b2cb0020c8a75393911489ad18206e0674e4973a53612dede8614d1aac423c"
assert len(qualities) == len({q["id"] for q in qualities}) == 235
ids = {q["id"] for q in qualities}
examples = json.loads((root / "examples.json").read_text())["examples"]
assert len(examples) == 6
assert sum(len(e["support_probabilities"]) for e in examples) == 1410
assert sum(len(e["candidate_reviews"]) for e in examples) == 318
for example in examples:
    assert set(example["support_probabilities"]) == ids
    paragraphs = {p["id"] for p in example["source_paragraphs"]}
    for review in example["candidate_reviews"]:
        assert review["quality_id"] in ids
        assert set(review["paragraph_ids"]) <= paragraphs
print("235 unchanged quality records; six complete uncapped examples; 318 review records valid")
PY
git diff --check
git diff --name-only -- app db test config lib
```

Owner acceptance / merge: Pending.

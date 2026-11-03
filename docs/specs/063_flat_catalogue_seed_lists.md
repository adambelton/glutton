# 063 — Use plain YAML lists for both catalogue seed files

Status: Accepted  
Owner: Film knowledge

## Goal

Remove unused vocabulary version metadata and the qualities wrapper so both one-time catalogue seed files have the same top-level YAML list structure.

## Scope

- Remove `version` and `qualities` root keys from config/quality_vocabulary.yml, preserving every quality entry and its order exactly.
- Read the vocabulary list directly in the seed loader and existing rollback test; document the common list structure.

## Scope restrictions

- No definition/category/default changes, schema or database changes, reseeding development, provider calls, new identifiers, idempotency, UI, other-domain changes or edits to historical research JSON.
- Preserve the existing one-time transactional seed and its observable failure behaviour. No new importer abstraction or schema-validation layer.

## Acceptance criteria

- **AC1:** Both runtime seed files are top-level YAML lists, with all nine categories and 235 qualities unchanged.  
  Check: parse both files, compare vocabulary entries exactly to the retained baseline after mapping facet to quality_category_name, and run existing seed/rollback tests.  
  Result: Passed — a local `bundle exec ruby -r yaml -r json` comparison verified both root values are Arrays, with nine categories and 235 quality entries, and the entire ordered vocabulary exactly equals the retained baseline after mapping facet to quality_category_name and omitting research IDs. Existing seed and forced-late-failure rollback tests passed as part of full CI. No category entry or vocabulary meaning changed.
- **AC2:** Loader and documentation agree with the plain-list format; required checks pass.  
  Check: full CI, eager loading, whitespace and retained-baseline preservation. No runtime vocabulary wrapper access or version metadata remains.  
  Result: Passed — `PARALLEL_WORKERS=1 bin/ci` passed: 487 tests / 6,109 assertions, zero failures/errors/skips; 235 Ruby files clean, gem/importmap audits clean, Brakeman zero warnings. `bin/rails zeitwerk:check` passed with the standard excluded-mailer-preview notice. `git diff --check` and `git diff --exit-code -- docs/film_qualities .obsidian` passed. Source inspection confirms the loader iterates the YAML list directly and the rollback test reads its last entry directly. README describes both root values as plain YAML lists.

## Implementation notes

Removed only the two vocabulary root fields and added a header comment matching the category-file convention. Both files retain their YAML document marker and top-level sequence of named entries. Removed vocabulary wrapper access from the loader and rollback test; the retained research JSON and its existing test access remain unchanged. README and plan reflect the result. No migration, development reseed, provider call or data edit was needed.

Reproduce the independent data check with `bundle exec ruby -r yaml -r json`: load both config YAML files, require Array root values with lengths 9 and 235, and compare the vocabulary array to `JSON.parse(File.read("docs/film_qualities/vocabulary.json")).fetch("qualities").map { |q| { "name" => q.fetch("name"), "match_rule" => q.fetch("match_rule"), "not_sufficient" => q.fetch("not_sufficient"), "quality_category_name" => q.fetch("facet") } }`. All ordered entries matched. The full CI command above additionally verifies actual persistence, category defaults and transactional rollback.

Owner acceptance / merge: Implementation requested on 3 November 2026; result pending review, not merged.

Owner delivery approval, 3 November 2026: final implementation accepted, including the subsequent simplifications; PR and merge after passing CI authorised. Actual merge pending under task 064.

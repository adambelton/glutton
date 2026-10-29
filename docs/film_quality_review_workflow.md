# Initial catalogue enrichment and admin quality improvement

Status: Ready for review — release direction clarified by owner on 29 October 2026; implementation details remain proposed.  
Owner: Film knowledge. [Task 052](specs/052_film_quality_review_workflow.md), [requirements](film_quality_requirements.md).

The initial release imports films from TMDB, enriches them with maintained Wikipedia plot/context and assigns qualities within **individually configured category ceilings**. This supersedes the former global-20 proposal. Admin category weights are a separate planned scoring control, initially 1 for every category; subgenres 2 and tropes 4–5 are illustrative ceiling candidates, not adopted defaults. Bulk seeding and user-requested missing-film imports use the same path. Admins improve the vocabulary and film associations; community editing is deferred. The previous contributor/submission/publisher proposal is superseded.

## Catalogue lifecycle

1. **Find and import:** bulk seed input or a user's TMDB search selects a specific TMDB film identity. Deduplicate into the canonical Film knowledge catalogue. An existing film is reused; repeat requests must not create duplicate films or repeat completed paid assessments unnecessarily. Importing does not itself create a personal Library entry or rating.
2. **Enrich:** resolve the correct Wikipedia film page, retain its identity/revision and attribution with useful plot/context. A missing or ambiguous page is an explicit coverage problem, not permission to use a similarly titled film or manufacture a plot. Retain the metadata record; show pending/incomplete enrichment rather than claim a completed quality assignment. Exact retry/fallback and readiness rules need their implementation spec.
3. **Assign initially:** JEV evaluates supplied context against defined qualities. A separate, explicit selection policy yields accepted qualities within each category's configured maximum without padding. Run this as a system operation for both bulk and on-demand imports; do not require an admin to review every seed film before it can progress. Keep evidence, definitions and run provenance inspectable. Failed/incomplete runs must not be labelled successful; expose exceptions for admin attention.
4. **Improve:** admins tune definitions and correct film associations through the tools below. Re-running an import must not overwrite those corrections. A deliberate later reassessment needs its own comparison/apply policy; a retry of initial work must check freshness and whether assignment has already completed.

The initial selection rule is still undecided. Equal base treatment does not choose which candidates occupy each category's available slots. Confidence can be examined quantitatively, but it is not an enjoyment weight. Do not carry the previous manual 17-quality example forward as an automated policy, silently choose a threshold/top-20 algorithm, or impose category quotas/importance guidance. Settling a practical initial assignment policy is part of the next pipeline design, not an invitation to resume open-ended tuning.

## Scheduled and manual source maintenance

Periodic syncing is the preferred initial direction for **both TMDB metadata and Wikipedia context**. Cadence, eligible records, change detection, retries and operating limits remain to be specified. A shared scheduling approach does not mean identical provider intervals or a generic workflow engine. No callback dependency is assumed or required by this proposal.

Plot corrections happen on Wikipedia, then sync into Glutton. The canonical film screen can show the external page and sync status; it is not a second plot editor. Metadata and plot refresh update their own source information/provenance. Scheduled source refresh alone does not automatically replace accepted qualities or rescore ratings/recommendations; its quality-check policy remains to be specified. Admin manual sync explicitly includes the comparison described below. Preserve the evidence reference used by an existing assignment rather than silently substituting a newer paragraph under it; exact storage/retention remains to be specified.

### Manual sync and quality check

The admin canonical film screen offers manual syncing from TMDB, Wikipedia or both. After a successful sync, run a JEV quality check using the latest available context and current definitions, then use the same versioned selection policy as initial assignment to produce a proposed set within each category's configured maximum. Run the check even when the selected provider reports no source change: this is an explicit admin request to compare the current result. Missing/ambiguous context or a provider/check failure must be visible; do not label an old or incomplete result as a successful fresh check. A successful source update can remain saved if the subsequent quality check fails, with separate sync/check statuses and retry of the failed stage.

Show two comparisons: the new proposal versus the film's current accepted set, and, when available, versus the previous machine-selected set. This distinguishes new model differences from existing manual corrections without requiring a permanent archive of every historical film-quality set. Compare quality IDs and meaning revisions, not just count or order; support estimates are diagnostic context, not preference weights.

- **Same effective set:** show no quality changes; do not publish associations or request downstream rescoring.
- **Different set:** show proposed additions/removals and evidence beside any manual corrections. The admin can retain the current set or explicitly apply a reviewed change under the same category-limit and freshness rules. Sync/check alone never overwrites the accepted set.
- **Changed inputs during the check:** mark the result stale if source, definition, selection-policy or accepted-set revisions changed. Do not apply it over newer work.

Record the source/context, vocabulary, question/model and selection-policy versions used for comparison. A changed result may come from these inputs or model variability; it is not proof that Wikipedia changed substantially. Most syncs may yield the same set, but stability is an expectation to observe, not a tested guarantee. The actual initial selection rule remains undecided; “same selected set” means the same category-limited identities/meanings, not a new importance ranking.

## Admin tools

These three interfaces are admin-only in the initial release. Ordinary users can search TMDB and request a missing-film import; they cannot edit canonical metadata/quality associations, definitions or discovery cases. The canonical film catalogue belongs to Film knowledge and is distinct from each user's Library.

| Interface | Inspect | Allowed improvement |
| --- | --- | --- |
| Quality library | Immutable quality name/identity, category, definition/exclusions, revision context and currently associated films with evidence. | Tune an existing definition/exclusion and adjust category grouping. New concepts require explicit creation; do not silently repurpose an existing name. |
| Canonical film library | TMDB identity/metadata, Wikipedia page/revision and plot/context, enrichment/sync status, current qualities and their evidence. | Add/remove existing qualities manually; inspect the proposed diff and save with max-20, permission and freshness validation. Manual TMDB/Wikipedia sync triggers a quality comparison; applying differences is explicit. Plot editing remains on Wikipedia. |
| Expression investigation and testing | Actual expression, associated film/source context, relevant quality definitions, current film associations, model matches/non-matches and recorded admin judgment. | Investigate missing concepts or associations; propose a definition adjustment/new concept and compare test results before applying a deliberate production change. |

### Quality names and tuning

Quality names are immutable after creation, including cosmetic renames. This tightens the earlier allowance for quality renaming. Categories can still be renamed or reorganised without implying a semantic or scoring change. Definitions/exclusions can be tuned **within the same concept**; tightening wording must remain distinguishable from changing meaning. A different concept needs a new named quality rather than changing the old one to fit a failing example. Handling a mistaken name/retirement needs an explicit later rule, not a hidden rename exception.

Save definition revisions with enough identity/context to identify affected film and expression assessments. A meaningful definition change can require deliberate reassessment; grouping-only changes do not. Preserve historical meanings/contributions used by saved scoring. FilmAnalysis is retired under the owner decision; no independent archive of every previous film-quality set is required.

### Manual film corrections

An admin can add an existing quality even if JEV did not match it, supplying source/context and a reason, or remove a false/redundant match. Keep the model probability as recorded; do not fabricate or rewrite it to justify the correction. Show definitions/exclusions and added/retained/removed associations. Evidence may be attributed interpretation rather than an explicit plot fact; label that distinction. No two-person approval, contributor draft submission or moderation workflow is required.

Reject a set exceeding any configured category ceiling explicitly and preserve the edit; never silently trim it. Report stale, unauthorised, invalid and unchanged attempts honestly. Whether an admin may intentionally clear a set to zero and how coverage is displayed still need a bounded rule. A genuine accepted association change is the proposed downstream reassessment boundary, using agreed durable contracts and separately owned implementations. An evidence-only correction, unchanged set, test run or source refresh is not such a change.

## Learning from user expressions

Start with an admin examining an expression against its film, not an assumption that every unmatched phrase deserves a new label. Film knowledge may read relevant Ratings-owned evidence through authorised read paths; it does not edit original expressions, infer consent for public display, or take ownership of user profiles. The implementation must define appropriate admin access and minimal context before exposing real user text. No bulk export or live expression processing is performed by this design task.

The investigation should distinguish:

| Finding | Example / diagnostic | Possible deliberate action |
| --- | --- | --- |
| Existing quality, missing film association | A viewer praises sparse dialogue; the vocabulary already captures it but the film lacks that association. | Inspect film evidence and correct the film set if supported. |
| Existing concept, definition or matching weakness | The intended concept exists, but wording/context failed to capture the expression. | Test a bounded definition/input correction, including examples it should not match. |
| Missing quality | The expression describes a useful distinction none of the existing meanings captures. | Admin records the proposed concept and preference hypothesis, checks neighbours and tests it before explicit creation/assignment. |
| Category-level preference | The viewer discusses an aesthetic family rather than a single technique. | Investigate existing category/quality coverage. Do not automatically create category multipliers or turn it into an unrestricted preference. |
| Contextual or uncertain statement | Sarcasm, negation, a particular portrayal, an off-topic remark or inadequate source coverage. | Retain context, mark uncertain/no action; lack of a match is not proof of a vocabulary gap. |

An expression can suggest a quality missing from the film's current set, but is not automatically verified canonical film evidence. Corroborate any proposed association appropriately. A preference for one portrayal must not be broadened into liking the entire category.

A useful first testing view is side-by-side: original expression/film context; current definitions and outputs; proposed definition or named concept; changed matches and admin judgments. Include positive, negative/near-neighbour and untouched examples so an improvement on one phrase is not mistaken for general success. Record test inputs, definition/question versions, results and cost when tests are later authorised. JEV can evaluate explicit candidate meanings; a match/no-match answer alone does not discover and name an unknown concept. The first tool can let the admin formulate the candidate rather than require an automatic vocabulary generator.

Testing must not update live definitions, accepted film sets, ratings or recommendations. Applying a tested definition, creating a quality or correcting a film is a separate explicit admin action through its owning operation. Avoid automatic vocabulary growth from expression frequency or model suggestions. JEV remains the chosen assessment engine; no new prompt, provider call or production threshold is established here.

## Optional admin diagnosis example: Tumbbad

This earlier example was prepared under the former global-20 proposal. It has not been reselected or validated against the new category-specific limits; retain it as a contextual diagnosis example only.

**Illustration only, not an import gate or automated selection policy:** begin with no accepted qualities for this film. This is a made-up starting state for the walkthrough, not a claim about current database contents. Reuse the [retained example](film_qualities/examples.json): Wikipedia revision **1377060620**, 28 October 2026 question baseline. The source's paragraph IDs are used below. The definitions, source packet and probabilities are unchanged.

The model produced 50 candidates >=0.7, with more uncertain candidates available. The proposed set below has **17 qualities**, including one manually selected at 0.68. It is one defensible editorial proposal, not a uniquely optimal set or a measured preference hierarchy. Do not fill the remaining three slots automatically.

<!-- selected-qualities:start -->
| Proposed quality / existing ID | Recorded support | Evidence | Distinct claim retained |
| --- | ---: | --- | --- |
| Folk horror (`folk_horror`) | 0.91 | [P4](#tumbbad-p4), [P6](#tumbbad-p6), [P20](#tumbbad-p20) | Folk belief and ritual create the threat; the classification is also attributed in reception. |
| Body horror (`body_horror`) | 0.94 | [P6](#tumbbad-p6), [P7](#tumbbad-p7), [P8](#tumbbad-p8) | Bodily violation and deformation, rather than just the presence of a creature. |
| Ritual survival rules (`ritual_survival_rules`) | 0.95 | [P5](#tumbbad-p5), [P6](#tumbbad-p6), [P8](#tumbbad-p8) | Specific rules govern protection and escape. |
| Confining interiors (`confining_interiors`) | 0.87 | [P6](#tumbbad-p6), [P8](#tumbbad-p8) | The enclosed womb physically limits escape. |
| Slow-burn pacing (`slow_burn_pacing`) | 0.93 | [P19](#tumbbad-p19) | A critic explicitly describes the film as a slow burn; not inferred from decades of story time. |
| Minimal dialogue (`minimal_dialogue`) | 0.97 | [P11](#tumbbad-p11) | Explicit description of little dialogue in the completed film. |
| Gothic horror (`gothic_horror`) | 0.94 | [P17](#tumbbad-p17) | Gothic dread is an attributed aesthetic reading, distinct from the folk-belief mechanism. |
| Greed and corruption (`greed_and_corruption`) | 0.96 | [P7](#tumbbad-p7), [P8](#tumbbad-p8) | Acquisitive desire leads to harmful conduct and family damage. |
| Corrupting mentorship (`corrupting_mentorship`) | 0.91 | [P8](#tumbbad-p8) | A father teaches his child the harmful procedure. |
| Selfish character makes a sacrifice (`selfish_character_makes_a_sacrifice`) | 0.76 | [P8](#tumbbad-p8) | The greedy father changes course and takes the attack to save his son. |
| Children in danger (`children_in_danger`) | 0.94 | [P5](#tumbbad-p5), [P8](#tumbbad-p8) | A child faces injury and direct attack; this is content, not a predicted viewer response. |
| Sustained dread (`sustained_dread`) | 0.95 | [P12](#tumbbad-p12), [P18](#tumbbad-p18) | Continuing dread is reported by the cinematographer and in reception; retain attribution. |
| Humans are the real monsters (`humans_are_the_real_monsters`) | 0.88 | [P20](#tumbbad-p20) | An attributed reading locates horror in human behaviour, rather than simply counting human villains. |
| Villain-centred identification (`villain_centred_identification`) | 0.68 | [P5](#tumbbad-p5), [P7](#tumbbad-p7), [P8](#tumbbad-p8) | Manual proposal: the story follows the harmful protagonist's goals and private actions; this is narrative proximity, not approval. |
| Breaking an inherited cycle (`breaking_an_inherited_cycle`) | 0.9 | [P8](#tumbbad-p8) | The son refuses the dangerous practice offered by his father. |
| Bittersweet survival (`bittersweet_survival`) | 0.73 | [P8](#tumbbad-p8) | The son survives while losing and burning his cursed father; the mixed outcome is the reviewer's reading. |
| Violence with lasting consequences (`violence_with_lasting_consequences`) | 0.95 | [P6](#tumbbad-p6), [P7](#tumbbad-p7), [P8](#tumbbad-p8) | Attacks leave continuing bodily affliction, rather than disappearing when the scene ends. |
<!-- selected-qualities:end -->

Review actions make the proposal's judgment visible:

- **Manual addition:** villain-centred identification (0.68) is not in the >=0.7 list. The admin selects it from the existing vocabulary and cites the protagonist's harmful private conduct, accepting that contextual reading without another model call or changing the recorded probability. It is not automatically interchangeable with morally compromised protagonist, which describes wrongdoing rather than narrative alignment.
- **Correction of a high match:** remove dehumanisation (0.76) from an initial suggestion. [P7](#tumbbad-p7) establishes bodily deformation but not people being treated as less than human. No global dehumanisation definition is changed.
- **Unresolved evidence:** leave prolonged suffering (0.60) unselected. [P6](#tumbbad-p6) establishes years of affliction, not extended screen presentation. More evidence could justify a later proposal; this is not a declaration of absence.
- **Avoid overlapping selections:** body horror covers the bodily-change claim here without also selecting grotesque transformation; the character-reversal quality is retained without also selecting costly self-sacrifice for the same act. The cycle-breaking ending is retained without also selecting moral refusal for the son's same decision. These are local editorial choices, not universal exclusion rules. Several distinct claims may still cite P8.
- **Supported alternatives remain possible:** occult/religious/creature labels, paternal legacy and other supported candidates are not declared false. This proposal uses more specific existing descriptions for their shared evidence. Another reviewer may propose a different non-duplicative set and explain it. There is no proof these 17 maximise enjoyment prediction or erase correlation bias.

Illustrative admin save: compare the current set with these 17 and inspect additions/removals and evidence. Validate permission, the configured category-limit invariants and the observed current-set/meaning revisions atomically. A concurrent change returns an explicit stale outcome, preserving the proposed edit; the admin reviews the fresh diff rather than overwriting it. The same IDs and meanings return an explicit no-change result. These are edit-safety requirements, not contributor submission or moderator approval states.

A manual source sync can rerun the quality check and compare against the current set; it neither accepts this example nor triggers rescoring without an accepted semantic change. Scheduled refresh checking remains a separate policy decision.

## Evidence used in the walkthrough

The summaries below are reviewer navigation notes, not replacement source packets. The full unmodified paragraphs, article identity, revision URL and attribution/licence remain in [examples.json](film_qualities/examples.json). Source: [Wikipedia revision 1377060620](https://en.wikipedia.org/w/index.php?oldid=1377060620), CC BY-SA 4.0; retain article attribution/history and source-specific exceptions. The worked selection contains spoilers.

### Tumbbad P4

The narrated mythology connects greed, a forgotten god, worship and the village's curse.

### Tumbbad P5

Childhood treasure-seeking exposes Vinayak to his threatening grandmother; a name invocation puts her to sleep. Sadashiv is injured and dies.

### Tumbbad P6

The afflicted old woman bargains over treasure knowledge and ending her suffering. The womb, flour circle, bait and escape procedure are described.

### Tumbbad P7

Vinayak repeatedly takes gold and tricks Raghav into danger. Raghav is fused into the womb; Vinayak burns him to end his suffering.

### Tumbbad P8

Greed damages family life. Vinayak trains his son; escalating the bait traps them. The father accepts the attack to free his son, becomes cursed, offers the treasure and is refused and burnt by the son.

### Tumbbad P11

The completed film is explicitly described as having minimal dialogue. The paragraph also includes earlier production stages; those do not establish every intended effect.

### Tumbbad P12

The cinematographer describes constant gloom and dread associated with lighting, rain and grey tone; distinguish reported result from other stated intentions in the paragraph.

### Tumbbad P17

Namrata Joshi describes Gothic dread and eerie expectancy. This is an attributed aesthetic reading.

### Tumbbad P18

Stutee Ghosh describes an ominous journey; other attributed responses discuss the film's spooky, affecting atmosphere.

### Tumbbad P19

J. Hurtado explicitly calls the film a slow burn; other critics' reservations are also present. No universal response is asserted.

### Tumbbad P20

Jonathan Barkan describes a focus on horror of human behaviour. Jacob Trussell identifies folk horror. Both remain attributed judgments.

## Bounded implementation handoff

The release scope is owner-directed; this document does not implement it. The next specs should each have one small Film knowledge outcome:

1. Use the decided roles: Quality, QualityCategory, Film and FilmQuality (the link), with direct current associations and Film-owned source context under task 054. Settle the initial category-limited assignment policy, missing-context handling and readiness outcomes. Task 043 supplies category configuration; neither it nor task 054 implements the import/assignment pipeline or admin UI.
2. Deliver one-film Wikipedia enrichment, then initial quality assignment, as independently verified capabilities using existing TMDB identity/import operations. Bulk seed and user search/import wiring consume these same operations in separate bounded slices; keep user Library mutations out of canonical import.
3. Specify provider-specific periodic refresh and admin manual sync with a follow-up quality comparison. Preserve manual corrections; keep source/check outcomes and explicit application separate. Set the scheduled quality-check policy independently.
4. Add admin quality-library and canonical-film editing in separately scoped UI/operation tasks. Admin authorisation needs an explicit implemented policy; being signed in is insufficient.
5. Add read-only expression investigation first, then a bounded comparison/testing capability. Explicitly scope any test execution/cost and subsequent application operation; no generic experimentation platform is required.

Before association/meaning changes cause downstream work, agree the semantic event contract under the [existing delivery mechanism](domain_events.md); implement publishers and receiving-domain subscribers in separate tasks. Ratings and Recommendations retain their mutations and historical contributions. No independent permanent association archive or public community governance is assumed.

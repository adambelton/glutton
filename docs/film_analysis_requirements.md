# Film analysis requirements and evidence standards

Status: Provisional requirements — pilot-informed, awaiting owner review  
Owner: Film knowledge  
Decision date: 27 October 2026

## Purpose and sequence

Build an original, maintained account of each film that can support film-derived qualities and later community curation. Define the required analysis and evidence before selecting enrichment providers or implementing a pipeline.

TMDB import supplies the identity starting point. Existing import stores minimal identity, not the full metadata backbone; metadata enrichment is subsequent work. Validate a future analysis pipeline on a small varied sample before processing the intended 500-film catalogue. The existing 50-film research set and its provisional qualities remain exploratory, not an accepted production corpus.

Qualities emerge from film analyses, with expected overlap across films. Film–quality relationships are many-to-many. Consolidate equivalent concepts while preserving distinctions meaningful to viewer preferences; do not force films into an arbitrary pre-generated vocabulary. Rare qualities are not invalid solely because the initial sample has little overlap.

## Experiential structure and useful qualities

Organise analysis around the experiences a film offers and the evidence for them, rather than around filmmaking disciplines. Do not claim a universal audience response. Independent accounts of being frightened or disgusted by a particular scene are evidence of those reported experiences; they do not establish their prevalence across audiences.

The following questions define the approved starting experiential format, which remains open to refinement rather than a fixed taxonomy:

| Dimension | Required questions |
| --- | --- |
| Emotional character | What experiences of dread, sadness, exhilaration, disgust, wonder or amusement are reported or supported? |
| Tension and rhythm | How are sustained pressure, uncertainty, contemplation or relentless activity experienced and constructed? |
| Engagement | How does the film invite mystery-solving, interpretation, identification or distance? |
| Relationships and stakes | How do intimacy, grief, distrust, isolation and conflict contribute to the experience? |
| Intensity and explicitness | What makes the experience confrontational, graphic, restrained or psychologically disturbing? |
| Tone | What supports descriptions such as sincere, playful, bleak, absurd or unstable? |
| Resolution and aftermath | What accounts or scene evidence support relief, catharsis, ambiguity, despair or lingering unease? |

Violence primarily belongs under Intensity and explicitness: graphic or implied, brief or prolonged, stylised or realistic. Its emotional character, tone, stakes and rhythm can also matter. Distinguish depicted content from reported response: graphic violence may be experienced as comically exuberant, while implied violence may be experienced as distressing. Do not collapse these into a single violence-intensity score or infer enjoyment from explicitness.

Plot through the ending, characters, setting, significant sequences and craft observations remain necessary context and evidence. Identity/version, sources and revision history are supporting information. Technical execution explains an experience; it does not automatically become a recommendation quality. For example, fast moving camerawork may support an account of frantic energy without warranting a filmmaker-specific camera-technique quality. Neither the technical feature nor its experiential interpretation establishes whether an individual user enjoys it.

Analysis and quality dimensions share terminology where relevant, but need not have a one-to-one mapping. Not every analytical observation or section produces a quality. This supersedes the earlier discipline-based shared-dimensions proposal. A scene can support multiple experiential dimensions without duplicating or contradicting its underlying account.

Evaluate each proposed quality for:
- **Preference relevance:** a meaningful characteristic someone could seek out or avoid.
- **Transferability:** a recognisable experience connecting different films, beyond a shared creator.
- **Discrimination:** a useful distinction rather than a label applying to almost everything.
- **Reliable identification:** sufficiently consistent evidence for its presence.

Be skeptical of categories based on artistic execution or generic praise such as “excellent cinematography”. Do not categorically exclude craft-related characteristics if they demonstrate preference relevance. Overlap alone does not establish recommendation usefulness; predictive usefulness needs later evaluation against viewer evidence. Rare qualities are not automatically invalid.

Dimensions organise investigation without prescribing findings. Preserve experiences that do not fit and use the film sample to revise the format and vocabulary. Descriptive categories alone do not justify STI or distinct model behaviour.

## Evidence-led dossier structure

Present the evidence before derived qualities or dimension summaries. A dossier must be useful to a reader who has not seen the film and to a reviewer checking the basis of an interpretation.

1. **Chronological narrative:** describe the setup, character relationships and motivations, major decisions, turning points, consequences and ending. Preserve the connective events that explain how one situation leads to another. A short synopsis is an introduction, not the narrative evidence.
2. **Key moments and sequences:** describe the situation beforehand, what happens, relevant supported presentation details and the resulting change in knowledge, relationships, danger or agency. Include quiet and connective moments as well as conspicuous violence. Do not impose a shot-by-shot transcript or invented timings.
3. **Claim-specific evidence:** attach sources to meaningful facts or coherent groups; say which details agree, which are complementary, and which remain single-source or disputed. Link back to narrative/moment identifiers to avoid repeatedly retelling the same material.
4. **Reported responses:** attribute a person's experience to the supported scene or broader film context. Record missing scene-specific testimony as a gap, not an invitation to invent a response.
5. **Interpretation:** only then summarise experiential dimensions and propose qualities, referencing the evidence above. A label such as dread, grief or graphic violence cannot stand in for the scene that supports it.

The number of narrative sections and key moments follows the film and available evidence. The seven experiential dimensions do not imply seven narrative beats or any moment count. The pilot’s repeated counts were a drafting limitation, not a coverage standard. Future AI drafts use the [versioned prompt and OpenAI API run protocol](prompts/film_analysis/README.md); v1 is newly authored, not recovered pilot provenance.

Evidence depth is assessed by whether the reader can follow the causal story and inspect the basis for conclusions, not by length alone. Reviews that mainly supply evaluations cannot be stretched into scene documentation. Acquire additional evidence where possible and leave precise gaps where coverage remains inadequate. Model memory is not corroboration.

## Completeness

A complete analysis adequately covers the film's meaningful characteristics across these dimensions, with concrete examples where needed. There is no word count, scene quota or requirement to invent depth in every section.

Identify the film, relevant cut/version, release context and verified metadata. Describe the narrative through its ending; analyses may contain spoilers. Address significant sequences and how their elements contribute to the film, rather than merely attaching generic labels.

For each dimension, distinguish supported coverage, unresolved gaps and justified non-applicability. Unknown is not absent: missing information about sound design is not evidence of unremarkable sound. Known gaps may leave a draft useful but incomplete. A long bibliography does not establish completeness or accuracy.

## Claims and evidence

Distinguish:
- **Observation:** an identifiable feature of the finished film. State whether it was directly observed by a contributor or reported by a source; AI synthesis must not imply direct viewing.
- **Reported experience:** an attributed account of a person’s response, tied to the scene or film and viewing context where available. Agreement strengthens evidence that this response occurs, not that everyone or most people experience it. Different responses can coexist.
- **Reported fact:** externally established information, such as a production method or stated filmmaker intention. Intention is not proof of audience effect.
- **Interpretation:** a reasoned reading supported by identifiable observations or sources. Acceptance means defensible, not uniquely correct.

Evidence attaches to individual meaningful claims or coherent claim groups, not just the document as a whole. Preserve:
- The claim, its kind, film/version and relevant scene or section.
- Supporting or conflicting source references and the specific passage, section, page or timecode where available.
- What each source actually supports, distinguishing corroboration from complementary detail.
- Source author/publisher, URL or identifier, publication/revision information where available, and retrieval date.
- Known source dependencies, uncertainty, conflicts and review rationale.
- Analysis authorship and revision; for generated drafts, model and prompt versions and the source set used.

These are information requirements, not a prescribed table-per-claim schema.

Multiple independent sources are the preferred acceptance standard. Evaluate relevance, directness and independence rather than counting URLs. Reprints, copied articles and accounts derived from the same interview are not independent corroboration. A credible single-source claim may remain provisional; a later curator can supply evidence or direct observation. Do not automatically reject all rare or single-source observations, or silently present them as independently verified.

Corroboration means agreement about the same claim. Complementary evidence adds different detail. For example, a script can describe a scene's action and a review can confirm its presence in the released film. The review's description of framing may add visual context, but the script does not independently corroborate that framing. Subtitles can support dialogue context without establishing camera movement or an actor's delivery. A script may differ from the final cut.

Do not resolve contradictions by majority vote or smooth them into a confident composite. Check film identity, cut, source dependence and specificity; record unresolved alternatives and qualify affected claims. An interpretation must not acquire factual status merely because several critics repeat it. Model recall and fluent output are not independent sources.

## Source-use framework

The editorial model is ordinary research: consult multiple sources to produce original analysis, not reproduce those sources. Scripts and subtitles are eligible research inputs alongside reviews, interviews, production material, factual references and direct curator observation. No source is assumed complete. Source choice follows demonstrated coverage of the analysis requirements.

“Public record” is not a blanket reuse category. Distinguish individual facts, publicly accessible protected material, public-domain material, licensed material and original contributor work. For each prospective source, assess access, automated retrieval, internal retention, AI processing and public output separately. Record applicable terms/licence and attribution requirements, with unresolved questions explicit. Do not assume attribution or original output alone settles every input use. This document neither declares particular scripts/subtitles cleared nor imposes a new legal-review gate for every research item.

The starting source-use matrix for later provider evaluation is:

| Source kind | Analytical role | Access/use evidence to record |
| --- | --- | --- |
| TMDB and factual catalogues | Identity, credits and metadata | API terms, permitted fields/use, attribution and retention constraints |
| Openly licensed references | Plot, context and research leads | Applicable licence/version, attribution and reuse conditions |
| Reviews, interviews and production material | Craft, reported production facts and interpretation | Access method, applicable terms/permissions and supported processing/retention |
| Scripts and subtitles | Narrative, dialogue and scene context | Provenance, film/draft/cut match, access and applicable use permissions |
| Direct curator contributions | Observations, corrections and interpretation | Authorship, viewed version, supporting evidence and contribution terms |

Keep independently written analysis separate from retained source material; store only source content permitted and necessary for the agreed use. Do not turn the dataset into a mirror of articles, scripts or subtitles. Public output should contain original synthesis and appropriate references, with any quotations handled under their applicable basis.

Background references, checked 27 October 2026: [UK copyright exceptions](https://www.gov.uk/guidance/exceptions-to-copyright), [UK database rights overview](https://www.nationalarchives.gov.uk/terms-and-conditions/copyright/copyright-and-related-rights/), [US Copyright Office on factual databases](https://www.copyright.gov/register/tx-databases.html), [Wikimedia content reuse](https://developer.wikimedia.org/use-content/content/). These distinguish protected expression/collections and permitted uses; they are not a determination that a particular planned ingestion is lawful. The UK text-and-data-mining exception described in that guidance is specifically for non-commercial research.

## Review rubric and future curation

Review a draft against:
1. Correct film identity and version.
2. Adequate dimension coverage, narrative through the ending and concrete supporting sequences.
3. Claim-level source support, independence and accurate limits on what evidence establishes.
4. Clear separation of observations, reported experiences, reported facts and interpretations; no unsupported population-wide response claims.
5. Visible gaps, contradictions and alternative readings.
6. Original analytical wording, provenance and recorded source-use conditions.
7. Experiential organisation and explicit scrutiny of quality preference relevance, transferability, discrimination and reliable identification.

Record pass, revision needed or insufficient evidence for each criterion, with reasons. A generated draft is provisional and must not be labelled independently verified merely because generation or automated checks completed.

Long-term, community members or selected curators propose revisions; independent reviewers assess the exact proposed revision before acceptance. Authors cannot verify their own changes. Material changes require renewed review, and accepted revisions retain authorship, evidence and review history. Whether one or two independent reviewers are required, curator eligibility, disputes and moderation remain to be specified. Approval of interpretation means supported and defensible; competing readings may coexist.

Do not implement community accounts, review queues, voting or publication states in this documentation task. Preserve these requirements for later storage/workflow design.

## Future feedback from user expressions

The intended cycle is:

**Accepted film analysis → reviewed qualities and film associations → personalised discovery → original user expressions → proposed analysis improvements → independently reviewed, accepted analysis revisions.**

Accepted revisions may then require reassessment of film associations and affected derived preferences under the evolution requirements below. Feedback can corroborate an experience, reveal a previously undocumented experience, suggest a missing distinction or preserve contrasting responses. Improvement need not mean stronger consensus.

Expressions are first-hand accounts of individual experience, not proof of a universal response or of every factual detail mentioned. A specific account of disgust or amusement during a scene can support that experiential claim. A general “I loved it” does not establish which scene or quality caused enjoyment. Preserve context and avoid inferring more specificity than the user supplied.

Ratings retains ownership of original expressions and their association with ratings. Film knowledge may use eligible contributions as referenced evidence for its own proposed changes; it does not rewrite the user's expression or treat a model's interpretation as the original statement. Capture the contribution's identity/revision and the analysis claims it supports, with traceable provenance rather than independent copies presented as new testimony.

The cycle must learn from new observations rather than amplify its own conclusions:
- An expression is evidence once; repeat processing, quotations and derived summaries do not create independent sources.
- Inferred preferences, recommendation scores, generated analyses and automatic quality assignments are not new user testimony.
- Distinct contributors can corroborate an experience, but independence and context still matter. Leading prompts or recommendation wording may influence descriptions; discovery selects which users encounter a film.
- Responses from users selected for an expected preference are evidence of their experiences, not a representative measure of audience response.
- Retain conflicting responses, such as fear and amusement, when supported. Do not use majority agreement to erase a defensible minority experience.
- New feedback proposes an amendment; it does not automatically overwrite accepted analysis, create a quality or increase a score. Independent review applies to the proposed analysis revision.

Before enabling the mechanism, define contribution eligibility, consent/use expectations, attribution, public quotation versus internal use, and retention. Permission to use private expressions for personalisation is not automatically permission to publish them. Specify what replacement, withdrawal, account deletion or removal of an expression does to referenced analysis evidence and dependent results; neither indefinite retention nor automatic erasure of independently supported claims is assumed here. Rating currentness for scoring and eligibility as historical analysis evidence are separate policy questions.

Constructed cycle checks:
1. A user reports amusement at a scene previously described only through fear: propose adding a supported contrasting experience; preserve the original expression and review the amendment.
2. Several summaries reuse one expression: retain one underlying contribution, not several corroborating accounts.
3. An accepted amendment changes a film association: reassess affected derived results without changing raw user evidence or counting the same contribution again as new testimony.
4. A contributing expression is replaced or withdrawn: identify dependent claims through provenance and apply the future agreed eligibility/retention policy; do not silently assume the evidence remains valid.

Task 025 records this cycle only. No expression collection, source-sharing contract, subscription, job, consent UI, automated moderation or preference update mechanism is implemented or authorised. Future work must scope Film knowledge and downstream ownership explicitly before defining implementation contracts.

## Standalone analysis and comparison layers

Owner decision, 27 October 2026: the planned weekly Glutton podcast will follow two hosts watching one recommended film, then using the app to inspect the analysis and actual recommendation scores/reasons, discuss the plot and key moments, share their reactions and submit ratings/expressions, and finally compare those expressions with the earlier expectations. A selection may strongly suit both hosts or be a poor match for one. The public discussion can inform development and participation; it is not automatically representative user research.

Keep three distinct presentation layers:

| Layer | Responsibility |
| --- | --- |
| Standalone film analysis | Film narrative, key moments, reported experiences, evidence and film-quality associations; no host/user profile or personal prediction. |
| Recommendation/profile comparison | The actual engine's score and positive/negative quality contributions for a viewer, with the historical inputs and scoring rules that explain it. No invented scene-level predictions beyond what the engine computes. |
| Review/expression comparison | Relate the submitted rating and original expressions to film evidence/qualities and the earlier expectation; preserve agreement, disagreement, ambiguous matches and uncovered experiences. |

Analysis must support comparison without containing it. Give meaningful narrative sections, moments and claims references tied to their analysis revision, and trace film-quality associations to that evidence. An expression about a scene can require context beyond its quality labels. Preserve enough reference history to distinguish unchanged material from corrected, split or removed moments. Do not force an expression into a quality when the analysis does not support the match.

The podcast reads the analysis after watching but before discussion and expression submission. Record that exposure as evaluation context, rather than treating those responses as blind predictions or independent corroboration of the analysis they have just read. Each host remains a distinct source; agreement is not audience prevalence. Original eligible expressions may inform the separately reviewed feedback cycle, but comparison results and generated explanations are not new testimony.

## V1 draft and quality workflow

The initial version needs a reliable revision mechanism, not a perfect or final analysis format. A person or AI can author an analysis draft against an existing Film. Both use the same content, evidence and lifecycle rules; generation is an optional authoring mechanism, not a different analysis type.

1. Create a draft with narrative, key moments, evidence references and explicit gaps.
2. Propose quality candidates from that analysis. Candidates are editable: change names, evidence or dimension, select an existing shared quality, add candidates or remove unsuitable ones before publication. Candidate generation does not publish vocabulary or affect recommendations.
3. Review and publish the chosen draft and candidates. Resolve existing shared qualities or persist genuinely new qualities, then persist the analysis-quality links. These writes, publication and predecessor supersession form one atomic operation. Failure leaves the previous active analysis and vocabulary unchanged.
4. To revise active knowledge, create another editable draft and regenerate or edit its candidates. Preserve the old analysis and its quality associations; do not edit published content in place.

Owner review of task 028: clients call `film.edit_analysis!` and `film.publish_analysis!`. Film creates or reuses its unpublished draft internally, copying current published content and candidates when starting a revision. Omitted edit fields retain their values; explicit empty values clear them. Publishing without pending changes is an explicit failure. Each film has at most one editable draft alongside its current analysis. Further changes edit that draft until publication; accepted versions remain immutable. The draft stores `content` and an editable `quality_candidates` array. Shared vocabulary is `FilmQuality`; dimensions are constants in `FilmQuality::Dimensions`, with localized labels, rather than editable records. There is no origin classification or predecessor field. Separate authoring/run provenance is deferred until its retention requirements are defined; source evidence remains in the content. The future API run protocol remains separate from this persistence task.

Quality matching should be explicit and predictable; V1 does not require automatic semantic deduplication. Specific self-explanatory names and reusable identities allow overlap across films. Dimensions organise qualities without requiring a rigid one-to-one mapping from analysis sections. The implementation spec defines minimal name uniqueness and candidate validation; it must not turn this workflow into a general taxonomy editor.

| Owning domain | Records and responsibilities |
| --- | --- |
| Film knowledge | Films, analysis drafts and versions with embedded quality candidates, shared film qualities, code-managed dimensions, and analysis-quality associations; publication and replacement. |
| Ratings | Ratings, original rating expressions, rating qualities and their scores/classifications, expression profiles and reassessment. |
| Recommendations | Recommendations and recommendation qualities, including the actual quality score contributions and total saved at computation time. |

Shared reads support computation without transferring ownership. A recommendation's saved score is its own historical output, not a synchronized copy of current Ratings or Film knowledge state. Film knowledge publication never mutates either downstream domain. Downstream recomputation belongs to separately scoped work. No new asynchronous domain communication or generic integration layer is introduced here.

The pilots are sufficient to proceed with this bounded V1 lifecycle. Additional research, automated enrichment, the 500-film expansion, community verification and expression feedback can follow separately; they are not publication-workflow prerequisites.

## Analysis publication and retained film qualities

Film qualities belong to a particular film analysis version. Preserve previous analyses and all their association sets when replacements are produced. Shared qualities are reusable identities with specific, self-explanatory names; no separate prose meaning/definition field is required. A materially different concept gets a different identity instead of silently changing an old name into a new concept. An ordinary wording correction need not create a new concept.

An analysis has `created_at`, nullable `published_at`, nullable `superseded_at` and optionally a `superseded_by_id` reference to its replacement. Creation does not make a draft authoritative. Validate the exact analysis and its proposed associations before publishing them together. At publication, atomically supersede the previous active analysis using the same effective timestamp. A pending or rejected replacement leaves the current version active. For V1, explicit publication is the approval step after review of the draft and candidates; a separate multi-person verification workflow is deferred. AI generation alone never publishes a draft. Future community contributions retain the independent-review requirement described above.

Film-quality associations inherit the analysis's validity period; separate invalidation timestamps on every association are not required. Superseding associations does not supersede or delete the shared qualities used by other films. Retain associations even when the replacement is identical or only prose changed; identical scoring inputs do not by themselves require downstream rescoring.

At time `t`, select an analysis with `published_at <= t` and (`superseded_at` absent or `superseded_at > t`). The interval includes publication and excludes supersession, so the replacement alone applies at the shared boundary. A first unpublished analysis supplies no active association set; missing analysis is not evidence that the film has no qualities. Publication time is distinct from creation or validation time.

Ratings have timestamped supersession too, but no draft/publication/commitment workflow for now: submission is effective immediately. See the [Ratings lifecycle decision](ratings_scoring_design.md#historical-ratings-and-quality-scores). Recommendations computes from rating qualities and analysis qualities, then persists its own recommendation qualities and their calculated score contributions alongside the recommendation total and scoring-rule version. Historical display uses that saved result, without reconstructing Ratings or Film knowledge state. Source-version references provide provenance; they do not replace the saved scores. Later recalculation produces a new result rather than rewriting the old recommendation. Pending processing must not be backdated as though its scores were available earlier.

These are agreed future lifecycle requirements. Models, persistence and recommendation comparisons are not implemented by this documentation task. The [repeat pilot](research/comparison_pilot/README.md), specified in [task 027](specs/027_comparison_ready_analysis_pilot.md), evaluates analysis readiness and an illustrative historical selection; real engine comparison remains dependent on the engine and actual viewer inputs.

## Evolving the format and derived preferences

Design requirements for future implementation, not a new processing contract or schema:

- Distinguish **format version** (the structure/questions), **analysis revision** (accepted content/evidence), **vocabulary revision** (quality identities, self-explanatory names and dimensions), and **assessment/scoring version** (how derived results were produced). Model/prompt versions are provenance, not substitutes for those distinctions.
- Keep accepted revisions identifiable and preserve the original evidence used. Record which input revisions produced film–quality associations and downstream assessments so affected results can be identified.
- A rename, reordered section or presentation-only format change does not itself change meaning or require rescoring. A newly added dimension may require further research before old analyses can supply it; missing coverage must remain unknown, not become a negative finding.
- Corrected or expanded accepted analysis requires review/reassessment of affected film–quality associations. Recompute user-derived results only where relevant input evidence or associations changed. Draft proposals do not silently replace accepted inputs.
- Keep a quality's identity stable when its meaning is unchanged. A different concept, split or merge needs distinct identities and explicit mapping/reassessment; do not silently reuse an old identifier with a different meaning or duplicate an old score across split qualities.
- Preserve original ratings and expression text. Reinterpretation changes derived assessments, not what the user originally said. Only current ratings contribute to current preferences; older evidence retains its historical role.
- Changed analysis/quality meanings may require reassessing expression-to-quality links, including explicitly expressed qualities. This is different from a profile-only change, which still affects only unexpressed and implicitly expressed scores under the [Ratings scoring design](ratings_scoring_design.md). Any expression-profile reinterpretation must derive exclusively from explicit expressions, never from film analysis or implied scores treated as user statements.
- Derived preferences and recommendation results must identify compatible completed inputs. Replacement must remove obsolete contributions, avoid double counting and reject late results for superseded inputs. Track pending/stale versus completed interpretation; do not present a partially recomputed mix as fully current.
- Film knowledge owns accepted analysis, vocabulary and film associations. Ratings owns interpretation of user evidence and preference recomputation; Recommendations owns its derived results. These are future impact requirements, not permission for Film knowledge to mutate those domains.

Before implementation, separately specify change detection, affected-user selection, failure/retry behaviour, processing boundaries and the user-visible policy during recomputation (for example, retain a clearly identified last completed result versus temporarily withhold it). Task 025 does not select a communication mechanism, publish events or introduce a generic invalidation engine.

Review evolution with these constructed scenarios:
1. Rename “Tension and rhythm” without changing meaning: preserve interpretations; no automatic score change.
2. Add a new experiential dimension: old analyses remain incomplete for it until assessed; do not invent zero-valued evidence.
3. Correct a scene account and remove an associated quality: reassess affected current-rating contributions and replace aggregates without altering raw ratings/expressions.
4. Split one quality into two: reassess film and expression evidence rather than copying the full old contribution into both.
5. Finish an older assessment after a newer analysis or rating was accepted: preserve provenance but do not let it overwrite the current result.
6. Reinterpret a directly expressed quality after a concept is split or replaced: retain the original expression and reassess its link; profile-only changes still cannot override direct evidence.

No recomputation infrastructure or completed scoring/profile implementation is claimed. Exact storage, compatibility and rollout policies await their owning task specs.

## Refinements from the five-film pilot

The [five-film research pilot](research/analysis_pilot/README.md) exercised the format with real source material; it did not independently verify the films or measure recommendation accuracy. Its report and drafts distinguish provisional conclusions from evidence gaps.

For each meaningful claim or coherent claim group, record:
- **Scope:** a scene, narrative phase, recurring pattern or whole-film account. Do not flatten a late escalation into constant intensity or mistake temporary relief for the final outcome. Exact timestamps are optional and must not be invented.
- **Evidence role:** depicted content, an attributed response, or an analytical inference. Distinguish the response of a character, a critic, a particular screening audience and a future user. The perpetrator's amusement is not an audience response; frightening content is not evidence of enjoyment.
- **Support status:** supported by inspected evidence, provisional/single-source, disputed, or not established. Support attaches to the particular claim, not a global confidence label for the entire film. Independent acceptance remains a separate review outcome.
- **Coverage gap and next check:** identify what would resolve it, such as direct viewing of a specified cut or another independent scene account.

One scene/evidence reference may support several dimensions without becoming several independent sources. Target film version and verified source/viewing version are separate; publication year, runtime and festival/distribution date cannot alone prove cut equivalence. Verify incidental factual metadata separately from treating a critic's experience as valid testimony.

Completing all seven sections only establishes draft coverage. Acceptance requires sufficient evidence and explicit gap review. A blank candidate-quality association means not established unless absence was actually assessed. Broad qualities that conflate different experiential mechanisms should be refined before matching, without forcing a permanent taxonomy or score model now.

## Illustrative rubric checks

These are constructed examples, not researched claims about real films:
- A screenplay describes an argument and an independent review confirms it appears in the final cut: support the scene's presence; qualify exact dialogue unless supported for that version.
- Three articles quote one interview about practical effects: one underlying reported account, not three independent confirmations.
- A script describes daylight while a review describes darkness: investigate draft/cut differences; do not accept a blended scene description.
- A review interprets a recurring room as an expression of grief: record an attributed interpretation and its scene evidence, not a verified production intention.
- No source discusses music: mark a coverage gap, not “the film uses no music”.
- A scene supports rural setting, sound-driven tension and grief: organise the analysis under shared dimensions while retaining the relationship to the same scene evidence.

- Two independent reviewers report disgust during one scene, while another describes amusement: record both experiences and their scene evidence, without claiming a universal or majority response.
- A reviewer describes rapid camera movement but no experiential effect: retain the craft observation; do not automatically infer frantic enjoyment or create a recommendation quality.

Task 026 supplies bounded source-based film research; task 027 supplies the comparison-ready repeat. Production provider coverage and recommendation accuracy remain unverified. These examples check the rules' coherence, not pipeline accuracy.

## Comparison-pilot findings

Task 027’s [repeat report](research/comparison_pilot/README.md) separates a located scene from a supported quality match. Ambiguous references, missing sound/effects evidence and uncertain reasons for dislike must remain visible rather than become forced associations. One expression can concern several moments; multiple references must not duplicate its evidential contribution. These are research/presentation requirements, not new domain contracts or implemented classification states.

Evidence references include the film and analysis version. Retain old references when a moment is corrected, retain the old grouping when split into more precise moments, and record a withdrawal without silently redirecting it to unrelated content. Candidate association replacement preserves the historical set; a prose-only change need not change scoring inputs. The constructed timeline checks these selection rules, not production transactions or recommendation reproduction.

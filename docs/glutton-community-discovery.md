# Glutton Community: Collaborative Horror Discovery

**Status:** Working product direction  
**Updated:** 23 November 2026

## Purpose

Glutton’s Community helps people discover and explore more of the horror they love. Horror is subjective. Members can share what they experienced, compare interpretations and introduce one another to films. Community enthusiasm can help surface a film, while each viewer decides whether it fits their taste.

A curation gives horror fans a lasting way to discover films through a theme or experience. Members can build on each other’s recommendations and return to the resulting list.

**Ratings, notes and personal assessments remain private.** Community participation is a deliberate act. Community results reflect what participants contributed, and Glutton Match reflects what Glutton predicts will suit the individual viewer. Community popularity stays outside private scoring and taste profiles.

## Community posts

Eligible members create **Community Curation** posts for themed film lists. Glutton creates **Film Debrief** posts on demand for watched-film conversations. The preferred direction is a shared Community board, with ordering, filtering and visibility of locked Debriefs to decide when Film Debrief is scoped.

## What makes a curation useful

A curation needs a discovery question, a structured way to participate and a film list that remains useful over time. Conversation can add context to an endorsement.

### Discovery question

A Discovery post poses a specific **discovery question or challenge** and defines how people may respond.

Examples:
- “I'm looking for bleak, hopeless supernatural horror. What should I watch?”
- “Nominate your five favourite folk-horror films.”
- “Rank the *Alien* films from best to worst.”
- “What's the best found-footage horror film?”

An activity has a prompt, a participation mechanism, rules/constraints, a participation state, and an aggregate result. Contextual discussion may be associated with the activity or individual contributions.

### Structured participation

The mechanism makes contributions comparable and aggregatable. Examples include suggesting a film, endorsing an existing suggestion, choosing up to five films, ordering a predefined or user-selected set of films, or selecting between candidates.

Exact rules (contribution limits, editing, duplicate handling, scoring, eligibility, and closure) should belong to each activity type rather than being assumed globally.

### Discovery artefact

The aggregate result is a destination in its own right. An artefact should be:
- **Browsable:** users can inspect the films and the resulting order, grouping, or level of support.
- **Actionable:** users can navigate to film details and use library actions as appropriate.
- **Personalised:** seen/unseen status, personal ratings, and Glutton match scores can appear alongside community outcomes.
- **Persistent:** useful beyond the immediate period of participation.
- **Evolvable:** updated when new valid contributions arrive, subject to the activity's state and rules.

Make clear what the result measures, such as endorsement count, nomination frequency or weighted rank.

### Film and Library integration

Contributions should reference canonical films wherever possible. Canonical links support film details, consistent metadata, deduplication and private Library actions. Future artefacts can show the viewer which films they have seen, how they rated them and their own Glutton Match where appropriate. If a format offers personal sorting, keep the original community order available. Give each artefact a stable home and make collections discoverable by subject, subgenre, experience and film.

### Find a curation by film

Someone searching Community for a film they like can find its Film Debrief and the curations that include it. A film can appear in several lists for different reasons. Each curation's prompt and member comments help readers decide which connection they want to explore. A member can start a curation with that film when the theme or experience they want is missing.

Asking for films like a particular title and collecting overlooked films both work as curation prompts. Top 5s, Rankings and Showdowns remain ideas for engagement. Their place in Glutton is open.

## Community Curation

See the [Community Curation architecture](community_niche_requests_architecture.md) for launch behaviour and implementation order.

### Ask the Community

A Community Curation post has a short title and a required written prompt describing a specific horror quality, theme, setting, experience or combination of characteristics. Widely known films can fit a niche as readily as obscure ones. The creation flow should help casual horror fans express what they are looking for in their own words.

Examples include horror set in isolated research facilities, found footage that builds dread through atmosphere, and films where the creature is never clearly revealed.

Authors can select canonical reference films marked Watched in their own Library. References are optional. Each one starts the list with one endorsement from the author and gives contributors a concrete example of the prompt. An author might start a list for slow-burn modern folk horror with two films that show what they mean. Other members can endorse those examples as the list grows.

### Nominate, endorse and discuss

Members choose **Endorse films** to add several films in one submission, with a separate optional comment for each film. They can respond again when they think of more films. The first endorsement introduces a film and later endorsements contribute to its total. Each member can have one active endorsement per film on the post across all responses. Each film appears once with its total, and its comments appear together with replies branching from each comment.

An endorsement allows one optional comment explaining why the film fits. The member can add it when endorsing or later while their endorsement and the request are open. They can delete the comment and add a fresh one under the same conditions. Any replies remain attached to the original conversation. The composer asks why the member endorses the film, how it fits the request and to avoid spoilers. The opening comment has no character limit. It starts a branching conversation. Other members can reply to it or to its replies. Comment and reply activity leave endorsement totals unchanged.

> The atmosphere is oppressive, and that sense of dread stayed with me for days.

An endorsement expresses agreement that a film fits the prompt. Members can endorse a film they personally disliked. The count measures relevance to the request independently of personal ratings, recommendations and Glutton Match. Keep comments and replies spoiler-free.

### Read community support and personal fit

The **Nominated Films** artefact is a living collection ordered by endorsement count. Members can revisit it, read visible conversations and follow canonical film links as eligible suggestions and endorsements change. The requester also sees their own Glutton Match where available, alongside the community ordering.

### Use Library from a request

Any member who can see a nominated film can use **Add to Watchlist** or **Mark Watched** for their own Library, including the requester. A member needs a Watched entry in their own Library to nominate or endorse a film, including when the author selects a reference. A contributor who has seen an eligible film can mark it Watched in the request flow before contributing. Registry owns any required film import and Library owns both collection actions. A rating or private notes are optional parts of the member’s own viewing record.

### Watchlist and post-watch follow-up

Requester Watchlist controls are deferred. Possibilities include restricting nominations to films the requester wants to watch, preferring those films while allowing others, or letting contributors filter candidates to the Watchlist. Any sharing should reflect the requester’s choice.

At launch, requesters can share feedback by editing an open unprotected request or appending an update to an open protected request. A later **Share Your Experience** action could let requesters identify films they intend to watch and return with an outcome. Feedback belongs in the request, separate from private ratings and notes. Selection, multiple outcomes, conclusion and reopening would need explicit lifecycle rules.

## Film Debrief

Members unlock a Film Debrief’s discussion content by marking the film Watched. They can reflect privately before joining the conversation or use the conversation to develop their own reaction before writing private notes.

Each film has at most one long-lived Film Debrief post. Its conversation forms a lasting record of how members experienced the film. Glutton creates it on demand when the first top-level comment is posted and supplies an introduction that names the film and invites spoiler-friendly discussion. Within that film thread, members can add multiple top-level comments, each with branching replies. The feature can reuse the comment structure and moderation from Community Curation. Whether to show that a discussion exists before a member unlocks it remains open.

### Experiential context

Discussions may eventually provide rich context: emotional responses, recurring interpretations, contradictions, memories, comparisons and subjective descriptions missing from conventional film metadata.

**Do not initially analyse, summarise or feed discussion content into Glutton's film-quality or recommendation models.** First observe what people actually say and whether it contains meaningful evidence. If future analysis proves useful, preserve distinctions among canonical film qualities, personal expressions and community observations, including uncertainty and disagreement. Clarify privacy and data-use expectations before such analysis.

## Classics and living collections

**Classic** is recognition for a curation that should become a permanent community discovery resource.

A Classic:
- Remains **open to participation indefinitely**; reaching Classic status means it cannot be closed.
- Continues to aggregate eligible contributions, so its artefact evolves over time.
- Has a durable, discoverable home beyond the normal stream of recent activity.
- Is selected for lasting discovery value. Niche horror topics can qualify.

Recognition determines which participation states a post can have.

| Recognition | Open | Closed |
| --- | --- | --- |
| Ordinary | Allowed | Allowed |
| Classic | Required | **Not allowed** |

A regular activity may close under its own rules. Promotion to Classic should ensure the activity is open and permanently prevents closure. The exact criteria and authority for promotion remain open. Manual curation is one possibility.

Historical snapshots might later show how a live collection has changed over time.

## Safety, trust and moderation

Publish a Community Code of Conduct at launch. Confirmed members can browse before onboarding. Before posting, they must explicitly accept the code and choose a public username and avatar. Members can pick a Glutton avatar or upload their own. The code explains which images are suitable for an avatar that appears throughout Community and that Glutton may remove an avatar after receiving a copyright complaint. Make the code and copyright contact easy to find.

Member participation at launch also needs reporting, moderation, spam prevention and protection of private information. The owner can grant and revoke the Community moderator role. Moderators work in Community, outside site Admin, and their role is independent of site superuser access. Prioritise reports of sensitive imagery and other conduct violations. If an uploaded image is removed, Glutton supplies a fallback avatar. Moderators can restrict a member to Glutton avatars separately from suspending Community access. See the [launch moderation design](community_niche_requests_architecture.md#moderation-and-deletion) for access, suspension and deletion rules.

Authors can delete a request before other members have contributed enough to protect it. Protection begins at three distinct other members with active endorsements or five visible comments from at least two other members. Once protected, the author can append updates or remove their attribution. The original request and discussion stay available. Account deletion follows the same retention rule. A comment with no replies disappears when deleted. When a comment has replies, the text and author are removed and the replies stay visible under a removal marker. Withdrawing a request or endorsement keeps its discussion visible and read-only.

Horror discussion should permit disturbing themes, interpretation and disagreement without permitting harassment or abuse. Moderation should protect people, not enforce a consensus on films.

## Release sequence and success signals

Build **Community Curation** first. Look at whether members start new lists with films they know and discover other films through existing curations. Look for relevant nominations, comments that explain why films fit, and repeat participation. Ask members whether they acted on nominations and found films they valued. If selection and outcomes are added later, look for requesters who watch a suggested film and return to share their experience.

Add **Film Debrief** next. Scope film search to surface the debrief and the curations that include a film. Observe what members discuss before considering other uses for their contributions.

Future work can explore richer personal Library context and Classic promotion and discovery. Following, likes, karma and a wider social feed are outside the launch scope.

## Community participation in product development

The community should be able to propose ideas, describe problems, support or challenge solutions, suggest alternatives and offer new directions. A lightweight **Ideas / Feedback** area may be sufficient initially.

Use community input to shape priorities. Evaluate ideas against these criteria.

- Alignment with the foundational principles.
- Evidence of an actual unmet need.
- Benefit to horror discovery and experience.
- Development and ongoing maintenance cost.
- Privacy, safety and trust implications.
- Sustainability for an independently developed product.

Make decisions and reasoning visible, including when a proposal is declined. The creator retains responsibility for the product’s principles.

### Other possibilities

Ideas to present for discussion and validation:

- **Private horror groups:** spaces for smaller circles of friends to discuss shared watches and plan future viewing.
- **Shareable taste profiles:** optional, selectively public representations of taste; never exposure of private ratings or notes.
- **Taste comparisons:** explore meaningful similarities and differences without simplistic objective rankings.
- **Shared or curated film collections:** themed collections, possibly emerging from suggestions and watchlists.
- **Community viewing events:** shared horror rituals and thematic watch activities.
- **Collaborative recommendations:** film discovery informed by multiple people's preferences.

These are possibilities, not a fixed roadmap. Other, better ideas may emerge from users.

## Agreed language

| Concept | Terminology |
| --- | --- |
| Social area | **Community** |
| Post types | **Community Curation** and **Film Debrief** |
| Theme and community film list | **Community Curation post** |
| Contribute films to a post | **Endorse films** |
| Instruction to requester | **Describe the kind of horror experience you're looking for** |
| Support an existing nomination | **Endorse** |
| Optional opening text attached to an endorsement | **Comment** |
| Respond to a comment or reply | **Reply** |
| Films in a request, ordered by endorsement count | **Nominated Films** |
| Possible post-watch follow-up | **Share Your Experience** / **Outcome** |
| Watched-film discussion | **Film Debrief** |
| Glutton's personalised discovery | **Recommendations** |
| Product-development proposals | **Ideas** / **Feedback** |

The action and field labels above are working UI language. An endorsement signals a film’s fit with a request. A Recommendation comes from Glutton and reflects the viewer’s preferences.

## Open product questions

### Community Curation

- Optional extension after the initial curation work. An author could cap the curated artefact while keeping every endorsed film and its discussion visible. For example, a Top 5 horror films of 2026 curation could show the five highest-ranked films in the artefact. Settle ties at the cutoff and whether film search matches all endorsed films or only those in the artefact when scoping the extension.
- Would alternative sort orders help people explore nominations?
- Which Watchlist controls would help requesters and contributors?
- How should film selection, multiple outcomes, conclusion and reopening work if added?
- Which notifications would help members follow requests?

### Film Debrief experience

- How should top-level comments and branching replies be organised and surfaced?
- How should members find active discussions for films they have watched?
- Should members see that a discussion exists before they can read it?
- Should Glutton encourage private first impressions before members read other reactions?
- What experiential evidence, if any, emerges from real conversations?

### Community

- How should the board order and filter different post types once Film Debrief is live?
- How should useful activity be surfaced without maximising screen time?
- What is the simplest effective Ideas / Feedback mechanism?
- How should the feedback process scale with the community?

### Film search and Classics

- How should search order results and handle archived curations and locked Film Debriefs?
- How should Classic status be awarded, and who has authority to promote a post?
- How should people find evergreen collections by subject, subgenre, experience or film, and which personal filters and scores should they see?
